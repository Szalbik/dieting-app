# frozen_string_literal: true

require 'json'
require 'openai'

class Chat::Diet::ParsingPipeline
  # Token/time accounting read by the diet:benchmark task; production ignores it.
  Stats = Struct.new(:calls, :input_tokens, :cached_tokens, :output_tokens, :seconds, :source, keyword_init: true) do
    def self.empty
      new(calls: 0, input_tokens: 0, cached_tokens: 0, output_tokens: 0, seconds: 0.0, source: nil)
    end

    # Accepts both Chat Completions (prompt/completion_tokens) and Responses
    # (input/output_tokens) usage shapes.
    def record(usage)
      usage ||= {}
      self.calls += 1
      self.input_tokens += (usage['prompt_tokens'] || usage['input_tokens']).to_i
      self.output_tokens += (usage['completion_tokens'] || usage['output_tokens']).to_i
      details = usage['prompt_tokens_details'] || usage['input_tokens_details'] || {}
      self.cached_tokens += details['cached_tokens'].to_i
    end
  end

  attr_reader :stats

  def initialize(file_path, expected_meals_per_day: nil)
    @file_path = file_path
    @expected_meals_per_day = expected_meals_per_day
    @stats = Stats.empty
    @stats_lock = Mutex.new
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    extraction = Chat::Diet::MarkdownExtractor.new(@file_path).extract
    @stats.source = extraction.source
    day_chunks = Chat::Diet::DaySegmenter.new(extraction.pages).call
    image_set = Chat::Diet::PageImageSet.new(@file_path)

    days = day_chunks
      .map { |chunk| parse_day(chunk, extraction, image_set) }
      .sort_by { |day| day['day'] }

    days = Chat::DietMealConsolidator.new(
      days,
      expected_meals_per_day: @expected_meals_per_day
    ).call

    DietJsonValidator.validate!(days)
    days
  ensure
    @stats.seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started if started
    image_set&.cleanup
  end

  private

  def parse_day(chunk, extraction, image_set)
    result = structured_chat(
      day_prompt(chunk),
      day_schema,
      model: day_model,
      extraction: extraction,
      chunk: chunk,
      image_set: image_set
    )

    # Trust our own segmentation over the model's echoed "day" field.
    result.merge('day' => chunk.day)
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
          'items' => {
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
          },
        },
      },
      'additionalProperties' => false,
    }
  end

  def day_prompt(chunk)
    meal_count_hint = if @expected_meals_per_day.present?
      "This day should contain exactly #{@expected_meals_per_day} meals; merge accessory items (e.g. a standalone drink) into the meal they belong to if the source lists more."
    else
      'Include every meal present in the source for this day.'
    end

    <<~PROMPT
      Extract this entire diet day as structured JSON.

      Rules:
      - "day" must be #{chunk.day}.
      - Return every meal for this day, in order (breakfast, lunch, dinner, snacks as present).
      - #{meal_count_hint}
      - Include every ingredient as a separate entry. If one line contains multiple comma-separated ingredients, split them into separate entries.
      - Include dressing, sauce, salad, condiment, spice, and beverage ingredients when they belong to a meal.
      - Include the complete preparation instructions for each meal; put numbered steps on separate lines when the source contains numbered steps.
      - Nutrition is mandatory per meal. Prefer explicit values from the source; otherwise calculate realistic totals from the ingredients. Round to whole numbers.

      Day markdown (a table shows the meal columns for the day; the numbered
      headings below the table give per-meal ingredients/instructions):
      #{chunk.markdown}
    PROMPT
  end

  def structured_chat(prompt, schema, model:, extraction:, chunk:, image_set:)
    response = openai_client.chat(
      parameters: {
        model: model,
        messages: [
          {
            role: 'system',
            content: system_prompt,
          },
          {
            role: 'user',
            content: user_content(prompt, extraction: extraction, chunk: chunk, image_set: image_set),
          },
        ],
        temperature: 0.2,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'diet_parsing_day',
            strict: true,
            schema: schema,
          },
        },
      }
    )

    @stats_lock.synchronize { @stats.record(response['usage']) }
    json_str = response.dig('choices', 0, 'message', 'content')
    JSON.parse(clean_gpt_json(json_str))
  rescue Faraday::BadRequestError => e
    error_body = if e.respond_to?(:response) && e.response
      e.response[:body]
    elsif e.respond_to?(:response_body)
      e.response_body
    end

    raise "OpenAI API error: #{e.message}. Response: #{error_body}"
  rescue JSON::ParserError => e
    raise "Błąd parsowania JSON: #{e.message}"
  end

  def user_content(prompt, extraction:, chunk:, image_set:)
    return prompt unless extraction.source == :ocr

    [
      {
        type: 'text',
        text: <<~PROMPT,
          #{prompt}

          IMPORTANT: The extracted text may contain OCR or page-break errors. Use the attached page images as the source of truth when the text and image disagree.
        PROMPT
      },
      *image_set.image_parts_for(chunk.page_numbers),
    ]
  end

  def clean_gpt_json(text)
    text.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip
  end

  def system_prompt
    <<~PROMPT
      You are a dietitian-grade extraction engine for diet PDFs.
      Work only on the provided day.
      Do not invent other days.
      Always return valid JSON matching the schema.
    PROMPT
  end

  def openai_client
    @_openai_client ||= OpenAI::Client.new(
      request_timeout: 240,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def day_model
    Rails.application.config.x.openai.diet_parsing_model
  end
end
