# frozen_string_literal: true

require 'pdf-reader'
require 'openai'

class Chat::DietParserService
  def initialize(file_path)
    @file_path = file_path
  end

  def call
    text = extract_text_from_pdf(@file_path)
    normalized = normalize_text(text)
    prompt = build_prompt(normalized)

    response = openai_client.chat(
      parameters: {
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
content: 'Jesteś dietetykiem i ekspertem od wartości odżywczych. Przetwarzaj wszystkie dni diety — jeśli pdf zawiera 14 dni, zwróć wszystkie 14 w strukturze JSON.',
          },
          { role: 'user', content: prompt },
        ],
        temperature: 0.2,
      }
    )

    json_str = response.dig('choices', 0, 'message', 'content')
    JSON.parse(clean_gpt_json(json_str))
  rescue JSON::ParserError => e
    raise "Błąd parsowania JSON: #{e.message}"
  end

  private

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
      You are a professional dietitian and expert in nutrition data extraction. Your task is to process the following diet plan text and return a complete, valid JSON array representing all days and meals in the plan.

      **Instructions:**
      1. Parse all days in the diet (e.g., "Day 1", "Dzień 1", etc.). If days are not explicitly named, infer them based on meal groupings.
      2. For each day, extract all meals. For each meal, extract:
         - type (e.g., "breakfast", "lunch", "dinner", "snack")
         - name (if not provided, use the meal type)
         - ingredients: a list of objects with "product" and "quantity" fields
         - instructions (if available, otherwise leave as an empty string)
         - nutrition: an object with "kcal", "protein", "fat", "carbs" (all as numbers; if unknown, use null)
      3. If any value cannot be determined, set it to null (do not guess).
      4. Always include all days and all meals, even if some fields are missing.
      5. Do not include any comments, explanations, or markdown—return only a valid JSON array.
      6. Ensure the JSON is parseable and matches this schema exactly:

      [
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

      **Edge Cases:**
      - If a day or meal is incomplete, still include it with nulls for missing fields.
      - If the diet is for 14 days, return all 14 days, even if some are similar or repeated.
      - If the PDF is in Polish, return field names in English but preserve meal/ingredient names as in the source.

      **Diet Plan Text:**
      #{diet_text}
    PROMPT
  end

  def openai_client
    @client ||= OpenAI::Client.new(request_timeout: 240, access_token: Rails.application.credentials.dig(:openai, :api_key))
  end
end
