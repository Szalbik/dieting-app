# frozen_string_literal: true

require 'json'
require 'openai'

class Chat::Diet::ParsingPipeline
  def initialize(file_path, expected_meals_per_day: nil)
    @file_path = file_path
    @expected_meals_per_day = expected_meals_per_day
  end

  def call
    extraction = PdfTextExtractor.new(@file_path).extract
    segments = Chat::Diet::Segmenter.new(extraction.pages).call
    image_set = Chat::Diet::PageImageSet.new(@file_path)

    meals = segments.map do |segment|
      metadata = parse_meal_metadata(segment, extraction, image_set)
      ingredients = parse_ingredients(segment, metadata, extraction, image_set)
      instructions_and_nutrition = parse_instructions_and_nutrition(segment, metadata, ingredients, extraction, image_set)

      {
        'day' => segment.day_number,
        'position' => segment.meal_position,
        'meal' => {
          'type' => metadata.fetch('type'),
          'name' => metadata.fetch('name'),
          'ingredients' => ingredients.fetch('ingredients'),
          'instructions' => instructions_and_nutrition.fetch('instructions', ''),
          'nutrition' => instructions_and_nutrition.fetch('nutrition'),
        },
      }
    end

    days = meals
      .group_by { |entry| entry['day'] }
      .sort_by { |day_number, _| day_number }
      .map do |day_number, day_meals|
        {
          'day' => day_number,
          'meals' => day_meals.sort_by { |entry| entry['position'] }.map { |entry| entry['meal'] },
        }
      end

    days = Chat::DietMealConsolidator.new(
      days,
      expected_meals_per_day: @expected_meals_per_day
    ).call

    DietJsonValidator.validate!(days)
    days
  ensure
    image_set&.cleanup
  end

  private

  def parse_meal_metadata(segment, extraction, image_set)
    schema = {
      'type' => 'object',
      'required' => %w[type name],
      'properties' => {
        'type' => {
          'type' => 'string',
          'enum' => %w[breakfast lunch dinner snack],
        },
        'name' => {
          'type' => 'string',
          'minLength' => 1,
        },
      },
      'additionalProperties' => false,
    }

    prompt = <<~PROMPT
      Extract meal metadata from the provided diet segment.

      Return:
      - "type" as one of: breakfast, lunch, dinner, snack
      - "name" as the dish name visible in the segment; if no explicit dish name is present, use the meal heading

      Meal heading: #{segment.meal_label}
      Day number: #{segment.day_number}

      Segment text:
      #{segment.text}
    PROMPT

    structured_chat(
      prompt,
      schema,
      model: stage_model(:metadata),
      extraction: extraction,
      segment: segment,
      image_set: image_set
    )
  end

  def parse_ingredients(segment, metadata, extraction, image_set)
    schema = {
      'type' => 'object',
      'required' => ['ingredients'],
      'properties' => {
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
      },
      'additionalProperties' => false,
    }

    prompt = <<~PROMPT
      Extract only the ingredient list for this diet meal.

      Rules:
      - Include every ingredient as a separate entry.
      - Include dressing, sauce, salad, condiment, spice, and beverage ingredients when they belong to this meal.
      - If one line contains multiple comma-separated ingredients, split them into separate entries.
      - Preserve product wording from the source when possible.

      Meal type: #{metadata['type']}
      Meal name: #{metadata['name']}
      Day number: #{segment.day_number}

      Segment text:
      #{segment.text}
    PROMPT

    structured_chat(
      prompt,
      schema,
      model: stage_model(:ingredients),
      extraction: extraction,
      segment: segment,
      image_set: image_set
    )
  end

  def parse_instructions_and_nutrition(segment, metadata, ingredients, extraction, image_set)
    schema = {
      'type' => 'object',
      'required' => %w[instructions nutrition],
      'properties' => {
        'instructions' => {
          'type' => 'string',
        },
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

    prompt = <<~PROMPT
      Extract final preparation instructions and nutrition values for this diet meal.

      Rules:
      - Include the complete preparation process in "instructions".
      - If the meal contains separate instructions for dressing, sauce, salad, or side items, include them too.
      - Put numbered steps on separate lines when the source contains numbered steps.
      - Nutrition is mandatory. Prefer explicit PDF values. Otherwise calculate realistic totals from the provided ingredients.
      - Round nutrition values to whole numbers when needed.

      Meal type: #{metadata['type']}
      Meal name: #{metadata['name']}
      Day number: #{segment.day_number}

      Ingredients JSON:
      #{ingredients['ingredients'].to_json}

      Segment text:
      #{segment.text}
    PROMPT

    structured_chat(
      prompt,
      schema,
      model: stage_model(:instructions_nutrition),
      extraction: extraction,
      segment: segment,
      image_set: image_set
    )
  end

  def structured_chat(prompt, schema, model:, extraction:, segment:, image_set:)
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
            content: user_content(prompt, extraction: extraction, segment: segment, image_set: image_set),
          },
        ],
        temperature: 0.2,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'diet_parsing_stage',
            strict: true,
            schema: schema,
          },
        },
      }
    )

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

  def user_content(prompt, extraction:, segment:, image_set:)
    return prompt unless include_page_images?(extraction, segment)

    [
      {
        type: 'text',
        text: <<~PROMPT,
          #{prompt}

          IMPORTANT: The extracted text may contain OCR or page-break errors. Use the attached page images as the source of truth when the text and image disagree.
        PROMPT
      },
      *image_set.image_parts_for(segment.page_numbers),
    ]
  end

  def include_page_images?(extraction, segment)
    extraction.source == :ocr || segment.low_quality_text?
  end

  def clean_gpt_json(text)
    text.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip
  end

  def system_prompt
    <<~PROMPT
      You are a dietitian-grade extraction engine for diet PDFs.
      Work only on the provided segment.
      Do not invent other meals or other days.
      Always return valid JSON matching the schema.
    PROMPT
  end

  def openai_client
    @_openai_client ||= OpenAI::Client.new(
      request_timeout: 240,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end

  def stage_model(stage_name)
    Rails.application.config.x.openai.diet_parsing_models.public_send(stage_name)
  end
end
