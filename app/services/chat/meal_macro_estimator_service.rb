# frozen_string_literal: true

require 'json'
require 'openai'

# Estimates kcal/protein/fat/carbs for a hand-written recipe/meal from its
# name and ingredient list, via a single structured-output call.
class Chat::MealMacroEstimatorService
  def initialize(name:, ingredients:)
    @name = name
    @ingredients = ingredients
  end

  def call
    response = openai_client.chat(
      parameters: {
        model: model,
        messages: [
          {
            role: 'system',
content: 'You are a nutrition estimator. Return realistic totals, rounded to whole numbers where sensible.',
          },
          { role: 'user', content: prompt },
        ],
        temperature: 0.2,
        response_format: {
          type: 'json_schema',
          json_schema: { name: 'meal_macros', strict: true, schema: schema },
        },
      }
    )

    json_str = response.dig('choices', 0, 'message', 'content')
    JSON.parse(json_str.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip)
  end

  private

  attr_reader :name, :ingredients

  def prompt
    lines = Array(ingredients).map { |i| i.is_a?(Hash) ? "#{i['name']} - #{i['amount']} #{i['unit']}" : i.to_s }
    "Meal: #{name}\nIngredients:\n#{lines.join("\n")}\n\nEstimate total kcal, protein (g), fat (g), carbs (g) for this whole meal."
  end

  def schema
    {
      'type' => 'object',
      'required' => %w[kcal protein fat carbs],
      'properties' => {
        'kcal' => { 'type' => 'number' },
        'protein' => { 'type' => 'number' },
        'fat' => { 'type' => 'number' },
        'carbs' => { 'type' => 'number' },
      },
      'additionalProperties' => false,
    }
  end

  def openai_client
    @_openai_client ||= OpenAI::Client.new(
      request_timeout: 60,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def model
    Rails.application.config.x.openai.diet_parsing_model
  end
end
