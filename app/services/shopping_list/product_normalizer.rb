# frozen_string_literal: true

module ShoppingList
  class ProductNormalizer
    LEADING_DECORATION = /\A[\s"'`,;:.!?]+/.freeze
    TRAILING_DECORATION = /[\s"'`,;:.!?]+\z/.freeze

    def initialize(lemmatizer: PolishLemmatizer.new)
      @lemmatizer = lemmatizer
    end

    def call(raw_name:, canonical_name: nil)
      cleaned_raw = cleaned_name(raw_name)
      cleaned_canonical = cleaned_name(canonical_name)
      source_for_key = cleaned_canonical.presence || cleaned_raw
      normalized_tokens = normalized_tokens(source_for_key)

      {
        key: normalized_tokens.join(' ').presence || ProductSubstitution.normalize_name(source_for_key),
        display_name: cleaned_canonical.presence || cleaned_raw,
        normalized_tokens: normalized_tokens
      }
    rescue StandardError => e
      Rails.logger.warn("ShoppingList::ProductNormalizer failed for '#{raw_name}': #{e.message}")
      cleaned = cleaned_name(canonical_name).presence || cleaned_name(raw_name)
      normalized = ProductSubstitution.normalize_name(cleaned)
      { key: normalized, display_name: cleaned, normalized_tokens: normalized.split }
    end

    def cleaned_name(text)
      cleaned = ProductSubstitution.strip_quantity_from_name(text)
        .to_s
        .gsub(LEADING_DECORATION, '')
        .gsub(TRAILING_DECORATION, '')
        .squeeze(' ')
        .strip

      balance_parentheses(cleaned)
    end

    def normalized_name(text)
      ProductSubstitution.normalize_name(cleaned_name(text))
    end

    def normalized_tokens(text)
      cleaned_name(text)
        .split
        .filter_map do |token|
          lemma = @lemmatizer.lemma(token)
          lemma.presence
        end
    end

    def canonical_form?(label)
      cleaned = cleaned_name(label)
      return false if cleaned.blank?

      normalized_name(cleaned) == call(raw_name: cleaned)[:key]
    end

    def best_display_label(labels, canonical_name: nil)
      cleaned_canonical = cleaned_name(canonical_name)
      return cleaned_canonical if cleaned_canonical.present?

      candidates = labels.each_with_index.filter_map do |label, index|
        cleaned = cleaned_name(label)
        next if cleaned.blank?

        {
          label: cleaned,
          index: index,
          canonical_form: canonical_form?(cleaned)
        }
      end
      return cleaned_name(labels.first) if candidates.empty?

      counts = candidates.each_with_object(Hash.new(0)) { |candidate, acc| acc[candidate[:label]] += 1 }

      candidates
        .uniq { |candidate| candidate[:label] }
        .min_by do |candidate|
          [
            candidate[:canonical_form] ? 0 : 1,
            -counts[candidate[:label]],
            candidate[:label].length,
            candidate[:index]
          ]
        end
        .fetch(:label)
    end

    private

    def balance_parentheses(text)
      return text if text.blank?

      opening = text.count('(')
      closing = text.count(')')
      return text if opening <= closing

      "#{text}#{')' * (opening - closing)}"
    end
  end
end
