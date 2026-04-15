# frozen_string_literal: true

require 'pdf-reader'
require 'openai'

class Chat::ProductSubstitutionParserService
  SCHEMA_PATH = Rails.root.join('app', 'schemas', 'product_substitution_parser_schema.json').freeze

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    response = openai_client.chat(
      parameters: {
        model: 'gpt-4.1',
        messages: [
          {
            role: 'system',
            content: 'Wyciągnij z PDF pary zamienników produktów spożywczych. Dla każdego produktu bazowego zwróć listę zamienników. Zwróć tylko poprawny JSON zgodny ze schematem.',
          },
          { role: 'user', content: build_prompt(extract_text_from_pdf(@file_path)) },
        ],
        temperature: 0.1,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'product_substitutions_response',
            strict: true,
            schema: json_schema,
          },
        },
      }
    )

    content = response.dig('choices', 0, 'message', 'content')
    parsed = JSON.parse(clean_json(content))
    parsed['substitutions'] || []
  end

  private

  def build_prompt(pdf_text)
    <<~PROMPT
      Przetwórz poniższy tekst PDF i wyciągnij listę zamienników produktów.

      Zasady:
      - source: produkt bazowy.
      - replacements: lista produktów zamiennych.
      - Każdy zamiennik ma być osobnym elementem tablicy replacements.
      - Pomiń linie, które nie opisują zamienników.
      - Zachowaj nazwy produktów w języku źródłowym.

      Tekst PDF:
      #{pdf_text}
    PROMPT
  end

  def extract_text_from_pdf(path)
    PdfTextExtractor.new(path).call
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
