# frozen_string_literal: true

require 'json'
require 'openai'

# Generates a personalized diet (same days/meals/ingredients/nutrition JSON
# shape as Chat::DietParserService) from a calorie target and preferences,
# instead of extracting it from a PDF. Output passes through the same
# DietJsonValidator and PopulateDietFromJsonJob as a parsed diet.
class Chat::DietGeneratorService
  def initialize(diet)
    @diet = diet
    @prefs = diet.generation_prefs || {}
  end

  def call
    response = openai_client.chat(
      parameters: {
        model: model,
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_prompt },
        ],
        temperature: 0.4,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'diet_generation',
            strict: true,
            schema: response_schema,
          },
        },
      }
    )

    json_str = response.dig('choices', 0, 'message', 'content')
    days = JSON.parse(clean_gpt_json(json_str))['days']
    DietJsonValidator.validate!(days)
    days
  rescue Faraday::BadRequestError => e
    error_body = e.respond_to?(:response) && e.response ? e.response[:body] : e.message
    raise "OpenAI API error: #{e.message}. Response: #{error_body}"
  rescue JSON::ParserError => e
    raise "Błąd parsowania JSON: #{e.message}"
  end

  private

  attr_reader :diet, :prefs

  def days_count
    prefs['days_count'].presence || 1
  end

  def meal_slots
    Array(prefs['slots']).presence || %w[breakfast lunch dinner]
  end

  def macro_split
    prefs['macro_split']
  end

  def goal_label
    Diet::GOAL_MACROS.dig(prefs['goal'], 'label')
  end

  def system_prompt
    <<~PROMPT
      You are a dietitian generating a personalized diet plan.
      Return valid JSON matching the schema exactly, for exactly #{days_count} day(s).
      Vary meals across days — do not repeat the same meal every day.
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      Generate a #{days_count}-day diet plan.

      - Daily calorie target: ~#{diet.kcal_target} kcal per day (each day's meals should sum close to this).
      - Meals per day, in order: #{meal_slots.join(', ')}.
      #{goal_label.present? ? "- Diet goal: #{goal_label}." : ''}
      #{macro_split.present? ? "- Macro split target: #{macro_split['protein_pct']}% protein / #{macro_split['fat_pct']}% fat / #{macro_split['carbs_pct']}% carbs." : ''}
      #{prefs['preferences'].present? ? "- Preferences / exclusions: #{prefs['preferences']}" : ''}
      - Every meal needs realistic ingredients with quantities, preparation instructions, and calculated nutrition (kcal/protein/fat/carbs). Round to whole numbers.
      - Each meal's "type" must be one of: #{meal_slots.join(', ')}, matching its position in the day.
    PROMPT
  end

  def response_schema
    {
      'type' => 'object',
      'required' => ['days'],
      'properties' => {
        'days' => {
          'type' => 'array',
          'minItems' => days_count,
          'maxItems' => days_count,
          'items' => day_schema,
        },
      },
      'additionalProperties' => false,
    }
  end

  def day_schema
    {
      'type' => 'object',
      'required' => %w[day meals],
      'properties' => {
        'day' => { 'type' => 'integer', 'minimum' => 1 },
        'meals' => {
          'type' => 'array',
          'minItems' => 1,
          'items' => meal_schema,
        },
      },
      'additionalProperties' => false,
    }
  end

  def meal_schema
    {
      'type' => 'object',
      'required' => %w[type name ingredients instructions nutrition],
      'properties' => {
        'type' => {
          'type' => 'string',
          'enum' => %w[breakfast second_breakfast lunch afternoon_snack dinner snack],
        },
        'name' => { 'type' => 'string', 'minLength' => 1 },
        'ingredients' => {
          'type' => 'array',
          'items' => {
            'type' => 'object',
            'required' => %w[product quantity],
            'properties' => {
              'product' => { 'type' => 'string', 'minLength' => 1 },
              'quantity' => { 'type' => 'string', 'minLength' => 1 },
            },
            'additionalProperties' => false,
          },
        },
        'instructions' => { 'type' => 'string' },
        'nutrition' => {
          'type' => 'object',
          'required' => %w[kcal protein fat carbs],
          'properties' => {
            'kcal' => { 'type' => %w[number null] },
            'protein' => { 'type' => %w[number null] },
            'fat' => { 'type' => %w[number null] },
            'carbs' => { 'type' => %w[number null] },
          },
          'additionalProperties' => false,
        },
      },
      'additionalProperties' => false,
    }
  end

  def clean_gpt_json(text)
    text.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip
  end

  def openai_client
    @_openai_client ||= OpenAI::Client.new(
      request_timeout: 240,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def model
    Rails.application.config.x.openai.diet_parsing_model
  end
end
