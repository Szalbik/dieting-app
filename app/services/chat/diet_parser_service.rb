# frozen_string_literal: true

require 'pdf-reader'
require 'openai'

class Chat::DietParserService
  SCHEMA_PATH = Rails.root.join('app', 'schemas', 'diet_parser_schema.json').freeze

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    text = extract_text_from_pdf(@file_path)
    normalized = normalize_text(text)
    prompt = build_prompt(normalized)

    begin
      response = openai_client.chat(
        parameters: {
          model: 'gpt-4o',
          messages: [
            {
              role: 'system',
              content: 'Jesteś dietetykiem i ekspertem od wartości odżywczych. Przetwarzaj wszystkie dni diety — jeśli pdf zawiera 14 dni, zwróć wszystkie 14 w strukturze JSON. MUSISZ zawsze obliczać wartości odżywcze (kcal, białko, tłuszcz, węglowodany) dla każdego posiłku na podstawie składników, jeśli nie są wyraźnie podane w PDF.',
            },
            { role: 'user', content: prompt },
          ],
          temperature: 0.2,
          response_format: {
            type: 'json_schema',
            json_schema: {
              name: 'diet_parser_response',
              strict: true,
              schema: json_schema,
            },
          },
        }
      )

      json_str = response.dig('choices', 0, 'message', 'content')
      parsed_json = JSON.parse(clean_gpt_json(json_str))

      # Extract the array from the wrapped object response
      # OpenAI returns { "days": [...] } but we need just [...]
      days_array = parsed_json.is_a?(Hash) && parsed_json.key?('days') ? parsed_json['days'] : parsed_json

      # Fallback validation to ensure schema compliance (validate against original array schema)
      DietJsonValidator.validate!(days_array)

      days_array
    rescue Faraday::BadRequestError => e
      error_body = begin
        if e.respond_to?(:response) && e.response
          e.response[:body]
        elsif e.respond_to?(:response_body)
          e.response_body
        end
      rescue
        nil
      end

      error_message = "OpenAI API error: #{e.message}"
      error_message += ". Response: #{error_body}" if error_body

      Rails.logger.error(error_message)
      Rails.logger.error("Schema being sent: #{json_schema.inspect}")

      # Re-raise with better error message
      raise error_message
    rescue JSON::ParserError => e
      raise "Błąd parsowania JSON: #{e.message}"
    rescue DietJsonValidationError => e
      Rails.logger.error("Diet JSON validation failed: #{e.message}")
      raise e
    end
  end

  private

  def json_schema
    @json_schema ||= begin
      # Load the original array schema
      original_schema = JSON.parse(File.read(SCHEMA_PATH))

      # OpenAI requires root schema to be an object with additionalProperties: false
      wrapped_schema = {
        'type' => 'object',
        'properties' => {
          'days' => {
            'type' => 'array',
            'description' => original_schema['description'],
            'items' => original_schema['items'],
          },
        },
        'required' => ['days'],
        'additionalProperties' => false,
      }

      # Recursively add additionalProperties: false to all object schemas
      add_additional_properties_false(wrapped_schema)
    end
  end

  def add_additional_properties_false(schema)
    return schema unless schema.is_a?(Hash)

    # Add additionalProperties: false to object types
    if schema['type'] == 'object' && !schema.key?('additionalProperties')
      schema['additionalProperties'] = false
    end

    # Recursively process nested schemas
    schema.each do |key, value|
      case value
      when Hash
        schema[key] = add_additional_properties_false(value)
      when Array
        schema[key] = value.map { |item| item.is_a?(Hash) ? add_additional_properties_false(item) : item }
      end
    end

    schema
  end

  def extract_text_from_pdf(path)
    reader = PDF::Reader.new(path)
    reader.pages.map(&:text).compact.join("\n")
  end

  def normalize_text(text)
    # Reduce multiple blank lines to two newlines
    text.gsub(/\n{3,}/, "\n\n").strip
  end

  def clean_gpt_json(text)
    text.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip
  end

  def build_prompt(diet_text)
    <<~PROMPT
      You are a professional dietitian and expert in nutrition data extraction. Your task is to process the following diet plan text and return a complete, valid JSON object with a "days" property containing an array of all days and meals in the plan.

      **Instructions:**
      1. Parse all days in the diet (e.g., "Day 1", "Dzień 1", etc.). If days are not explicitly named, infer them based on meal groupings.
      2. For each day, extract all meals. For each meal, extract:
         - type (e.g., "breakfast", "lunch", "dinner", "snack")
         - name (if not provided, use the meal type)
         - ingredients: a list of objects with "product" and "quantity" fields
         - instructions (if available, otherwise leave as an empty string)
         - nutrition: MANDATORY - You MUST provide nutrition values for EVERY meal. Follow this priority:
      #{'     '}
           **Priority 1:** Extract explicit nutrition values from the PDF if present (look for tables, labels, or text near meals in formats like "kcal: 300", "300 kcal", "B: 8g", "T: 4g", "W: 60g")
      #{'     '}
           **Priority 2:** If not explicitly stated, CALCULATE nutrition values from the ingredients listed. Use your knowledge of standard nutrition databases:
           * Parse ingredient quantities (e.g., "50g oats", "1 banana", "200ml milk")
           * Look up standard nutritional values per 100g/ml for each ingredient
           * Sum up the total kcal, protein, fat, and carbs for all ingredients in the meal
           * Round to reasonable whole numbers
      #{'     '}
           **Examples of calculations:**
           - Oats: 100g = ~389 kcal, 17g protein, 7g fat, 66g carbs → 50g = ~195 kcal, 8.5g protein, 3.5g fat, 33g carbs
           - Banana (medium): ~105 kcal, 1.3g protein, 0.4g fat, 27g carbs
           - Chicken breast: 100g = ~165 kcal, 31g protein, 3.6g fat, 0g carbs
           - Rice (cooked): 100g = ~130 kcal, 2.7g protein, 0.3g fat, 28g carbs
      #{'     '}
           **IMPORTANT:** You are a nutrition expert. Use your knowledge to calculate realistic values. Only use null if an ingredient is completely unidentifiable or unquantifiable (extremely rare).
      #{' '}
      3. Always include all days and all meals with complete nutrition data.
      4. Always include all days and all meals, even if some fields are missing.
      5. The response must conform to the provided JSON schema (enforced by the API).
      6. Return the data as an object with a "days" property containing the array. Example structure:

      {
        "days": [
          {
            "day": 1,
            "meals": [
              {
                "type": "breakfast",
                "name": "Oatmeal with Fruit",
                "ingredients": [
                  { "product": "Oats", "quantity": "50g" },
                  { "product": "Banana", "quantity": "1" }
                ],
                "instructions": "Mix oats with water, cook, and top with sliced banana.",
                "nutrition": {
                  "kcal": 300,
                  "protein": 8,
                  "fat": 4,
                  "carbs": 60
                }
              }
            ]
          }
        ]
      }

      **CRITICAL NUTRITION REQUIREMENT:**
      - Nutrition values (kcal, protein, fat, carbs) are REQUIRED for every meal
      - If not explicitly stated in the PDF, you MUST calculate them from the ingredients
      - Use standard nutrition databases and your expertise as a dietitian
      - Round values to whole numbers (e.g., 195.3 kcal → 195 kcal)
      - Only use null in extremely rare cases where an ingredient is completely unidentifiable

      **Edge Cases:**
      - If a day or meal is incomplete, still include it with complete nutrition data calculated from ingredients.
      - If the diet is for 14 days, return all 14 days, even if some are similar or repeated.
      - If the PDF is in Polish, return field names in English but preserve meal/ingredient names as in the source.
      - For unknown quantities (e.g., "dowolna ilość" / "any amount"), use reasonable standard portions for calculations.

      **Diet Plan Text:**
      #{diet_text}
    PROMPT
  end

  def openai_client
    @client ||= OpenAI::Client.new(request_timeout: 240, access_token: Rails.application.credentials.dig(:openai, :api_key))
  end
end
