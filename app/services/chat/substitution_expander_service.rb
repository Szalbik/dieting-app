# frozen_string_literal: true

require 'openai'

class Chat::SubstitutionExpanderService
  SCHEMA_PATH = Rails.root.join('app', 'schemas', 'substitution_expander_schema.json').freeze

  def initialize(product_catalog:, existing_substitutions:)
    @product_catalog = product_catalog
    @existing_substitutions = existing_substitutions
  end

  def call
    return [] if @product_catalog.empty?

    response = openai_client.chat(
      parameters: {
        model: 'gpt-4.1',
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: build_prompt },
        ],
        temperature: 0.15,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'substitution_expander_response',
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

  def system_prompt
    <<~TEXT
      Rozszerzaj zamienniki produktów żywieniowych sensownie kulinarnie.
      Priorytet:
      1) Zastępstwa w tej samej funkcji w posiłku.
      2) Produkty dostępne w katalogu użytkownika.
      3) Unikaj absurdów (np. jogurt => woda w "jogurt z płatkami").

      Dodatkowe reguły domenowe:
      - Owoce mogą zamieniać się na inne owoce.
      - Pieczywo może zamieniać się na inne pieczywo.
      - Napoje mogą zamieniać się na inne napoje (np. herbata/kawa/woda), ale nie naruszaj sensu posiłku.
    TEXT
  end

  def build_prompt
    <<~PROMPT
      Katalog produktów użytkownika (name|category):
      #{catalog_lines}

      Aktualne zamienniki (source -> replacement):
      #{substitution_lines}

      Zwróć rozszerzenia zamienników tylko dla produktów obecnych w katalogu.
      Nie duplikuj istniejących par.
      Dla każdej propozycji podaj confidence 0..1.
    PROMPT
  end

  def catalog_lines
    @product_catalog.map { |entry| "#{entry[:name]}|#{entry[:category]}" }.uniq.join("\n")
  end

  def substitution_lines
    lines = @existing_substitutions.flat_map do |source, replacements|
      replacements.map { |replacement| "#{source} -> #{replacement}" }
    end
    lines.first(300).join("\n")
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
