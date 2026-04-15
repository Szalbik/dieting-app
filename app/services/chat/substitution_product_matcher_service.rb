# frozen_string_literal: true

require 'openai'

class Chat::SubstitutionProductMatcherService
  SCHEMA_PATH = Rails.root.join('app', 'schemas', 'substitution_product_matcher_schema.json').freeze

  def initialize(source_products:, diet_product_names:)
    @source_products = source_products.uniq
    @diet_product_names = diet_product_names.uniq
  end

  def call
    return [] if @source_products.empty? || @diet_product_names.empty?

    response = openai_client.chat(
      parameters: {
        model: 'gpt-4.1',
        messages: [
          {
            role: 'system',
            content: 'Dopasuj produkty bazowe z listy zamienników do nazw produktów z diety. Zwracaj tylko realne dopasowania semantyczne, unikaj słabych dopasowań.',
          },
          { role: 'user', content: build_prompt },
        ],
        temperature: 0.1,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'substitution_product_matcher_response',
            strict: true,
            schema: json_schema,
          },
        },
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    parsed = JSON.parse(clean_json(content))
    parsed.fetch('mappings', [])
  end

  private

  def build_prompt
    <<~PROMPT
      Dopasuj nazwy produktów bazowych z listy zamienników do nazw produktów występujących w diecie użytkownika.

      Zasady:
      - Dla każdego source_product zwróć 0..N matched_product_names.
      - Dopasowuj tylko gdy to ten sam produkt lub bardzo bliski wariant (np. "jogurt naturalny 2%" -> "Jogurt naturalny 2% tłuszczu").
      - Ignoruj przypadkowe podobieństwa.
      - matched_product_names MUSZĄ pochodzić wyłącznie z listy diet_product_names.

      source_products:
      #{@source_products.join("\n")}

      diet_product_names:
      #{@diet_product_names.join("\n")}
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
      request_timeout: 240,
      access_token: Rails.application.credentials.dig(:openai, :api_key)
    )
  end
end
