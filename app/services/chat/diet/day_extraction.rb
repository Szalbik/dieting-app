# frozen_string_literal: true

require 'json'
require 'openai'

# What both parsing strategies share: the per-day output schema, the extraction
# rules, model request params and the OpenAI client. A strategy only decides
# how the day's source (markdown text, page images, the PDF itself) reaches
# the model.
module Chat::Diet::DayExtraction
  MEAL_TYPES = %w[breakfast second_breakfast lunch afternoon_snack dinner snack].freeze

  DAY_SCHEMA = {
    'type' => 'object',
    'required' => %w[day meals],
    'properties' => {
      'day' => { 'type' => 'integer', 'minimum' => 1 },
      'meals' => {
        'type' => 'array',
        'minItems' => 1,
        'items' => {
          'type' => 'object',
          'required' => %w[type name ingredients instructions nutrition],
          'properties' => {
            'type' => { 'type' => 'string', 'enum' => MEAL_TYPES },
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
        },
      },
    },
    'additionalProperties' => false,
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT
    You are a dietitian-grade extraction engine for diet PDFs.
    Work only on the requested day.
    Do not invent other days.
    Always return valid JSON matching the schema.
  PROMPT

  module_function

  # DAY_SCHEMA plus the ingredient "category" enum, which comes from the DB
  # (seeded Category rows — same source of truth as Chat::ProductCategorizerService),
  # so it cannot live in the frozen constant.
  def day_schema
    schema = DAY_SCHEMA.deep_dup
    ingredient = schema['properties']['meals']['items']['properties']['ingredients']['items']
    ingredient['required'] = %w[product quantity category]
    ingredient['properties']['category'] = { 'type' => 'string', 'enum' => category_names }
    schema
  end

  def category_names
    Category.pluck(:name).presence || ['Inne']
  end

  def rules(day:, expected_meals_per_day:)
    meal_count_hint = if expected_meals_per_day.present?
      "This day should contain exactly #{expected_meals_per_day} meals; merge accessory items " \
        '(e.g. a standalone drink) into the meal they belong to if the source lists more.'
    else
      'Include every meal present in the source for this day.'
    end

    <<~PROMPT
      Extract this entire diet day as structured JSON.

      Rules:
      - "day" must be #{day}.
      - Return every meal for this day, in order (breakfast, lunch, dinner, snacks as present).
      - One meal slot in the source (e.g. "Przekąska I", "II śniadanie", "Podwieczorek") is ONE meal even when it lists several dishes (e.g. a skyr and a fruit): combine their ingredients, do not split it into two meals.
      - #{meal_count_hint}
      - Include every ingredient as a separate entry. If one line contains multiple comma-separated ingredients, split them into separate entries.
      - Include dressing, sauce, salad, condiment, spice, and beverage ingredients when they belong to a meal.
      - Give every ingredient the single best-fitting grocery "category" from the allowed list; use "Inne" only when nothing fits.
      - Include the complete preparation instructions for each meal; put numbered steps on separate lines when the source contains numbered steps.
      - Nutrition is mandatory per meal. Prefer explicit values from the source; otherwise calculate realistic totals from the ingredients. Round to whole numbers.
    PROMPT
  end

  # gpt-5.x are reasoning models: they take reasoning_effort, and only accept a
  # non-default temperature when effort is "none" (verified live 2026-09-28:
  # gpt-5.1 + temperature 0.2 + default effort parses fine). Keeping 0.2 at
  # effort "none" keeps the pre-strategy baseline byte-for-byte comparable.
  def chat_params(model:, reasoning_effort:)
    return { temperature: 0.2 } unless reasoning_model?(model)

    effort = reasoning_effort.presence || 'none'
    effort == 'none' ? { reasoning_effort: effort, temperature: 0.2 } : { reasoning_effort: effort }
  end

  def responses_params(model:, reasoning_effort:)
    return { temperature: 0.2 } unless reasoning_model?(model)

    effort = reasoning_effort.presence || 'none'
    params = { reasoning: { effort: effort } }
    effort == 'none' ? params.merge(temperature: 0.2) : params
  end

  def reasoning_model?(model)
    model.to_s.start_with?('gpt-5')
  end

  def client
    OpenAI::Client.new(request_timeout: 240, access_token: Rails.application.credentials.dig(:openai, :api_key))
  end

  def parse_json(text)
    JSON.parse(text.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip)
  rescue JSON::ParserError => e
    raise "Błąd parsowania JSON: #{e.message}"
  end

  # Surface OpenAI's error body — the Faraday message alone ("status 400") hides why.
  def with_api_errors
    yield
  rescue Faraday::BadRequestError => e
    body = e.respond_to?(:response) && e.response ? e.response[:body] : nil
    raise "OpenAI API error: #{e.message}. Response: #{body}"
  end

  # Runs block for every item, at most `concurrency` at a time, preserving
  # order. Every thread in a slice is joined before the first failure is
  # re-raised, so a caller's `ensure` (e.g. deleting the uploaded file) never
  # runs under still-active siblings.
  def in_parallel(items, concurrency)
    Array(items).each_slice([concurrency.to_i, 1].max).flat_map do |slice|
      threads = slice.map do |item|
        Thread.new(item) do |value|
          Thread.current.report_on_exception = false
          yield value
        end
      end
      outcomes = threads.map { |thread| settle(thread) }
      failure = outcomes.find { |outcome| outcome.is_a?(Exception) }
      raise failure if failure

      outcomes
    end
  end

  def settle(thread)
    thread.value
  rescue StandardError => e
    e
  end
end
