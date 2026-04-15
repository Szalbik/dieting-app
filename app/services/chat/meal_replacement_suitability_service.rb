# frozen_string_literal: true

require 'openai'

class Chat::MealReplacementSuitabilityService
  SCHEMA_PATH = Rails.root.join('app', 'schemas', 'meal_replacement_suitability_schema.json').freeze

  def initialize(meal_name:, ingredient_names:, current_product_name:, base_product_name:, candidate_names:)
    @meal_name = meal_name.to_s
    @ingredient_names = ingredient_names
    @current_product_name = current_product_name.to_s
    @base_product_name = base_product_name.to_s
    @candidate_names = candidate_names
  end

  def call
    return @candidate_names if @candidate_names.size <= 2

    response = openai_client.chat(
      parameters: {
        model: 'gpt-4.1-mini',
        messages: [
          {
            role: 'system',
            content: 'Oceń, które zamienniki mają kulinarny sens w kontekście konkretnego posiłku. Zwracaj tylko sensowne opcje.',
          },
          { role: 'user', content: build_prompt },
        ],
        temperature: 0.1,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'meal_replacement_suitability',
            strict: true,
            schema: json_schema,
          },
        },
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    parsed = JSON.parse(clean_json(content))
    allowed = Array(parsed['allowed_products'])
    allowed.select { |name| @candidate_names.any? { |candidate|
 ProductSubstitution.normalize_name(candidate) == ProductSubstitution.normalize_name(name) } }
  end

  private

  def build_prompt
    <<~PROMPT
      Oceń zamienniki dla składnika w konkretnym posiłku.

      Posiłek: #{@meal_name}
      Składniki posiłku:
      #{@ingredient_names.join("\n")}

      Aktualny produkt: #{@current_product_name}
      Produkt bazowy: #{@base_product_name}
      Kandydaci do zamiany:
      #{@candidate_names.join("\n")}

      Zasady:
      - Zwróć tylko kandydatów, którzy mają realny sens w tym posiłku.
      - Odrzuć kandydatów psujących charakter posiłku (np. jogurt -> mleko w "jogurt z płatkami", jeśli to nie jest równoważny zamiennik składnika).
      - Jeśli nie masz pewności, pomiń kandydata.
    PROMPT
  end

  def clean_json(text)
    text.to_s.gsub(/\A```json\s*\n?/, '').gsub(/```$/, '').strip
  end

  def json_schema
    @_json_schema ||= JSON.parse(File.read(SCHEMA_PATH))
  end

  def openai_client
    @_openai_client ||= OpenAI::Client.new(
      request_timeout: 120,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end
end
