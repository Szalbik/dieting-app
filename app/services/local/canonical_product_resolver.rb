# frozen_string_literal: true

module Local
  class CanonicalProductResolver
    MIN_FUZZY_SCORE = 0.9

    def initialize(user:)
      @user = user
    end

    def call(raw_name:, preferred_name: nil)
      cleaned = cleaned_name(raw_name)
      return if @user.blank? || cleaned.blank?

      canonical = resolve_existing(raw_name: cleaned)
      canonical ||= create_canonical!(cleaned, preferred_name: preferred_name)
      ensure_aliases!(canonical, [raw_name, preferred_name, cleaned])
      canonical
    end

    def resolve_existing(raw_name:)
      cleaned = cleaned_name(raw_name)
      return if @user.blank? || cleaned.blank?

      normalized = ProductSubstitution.normalize_name(cleaned)
      stem = stem_signature(cleaned)

      exact = @user.canonical_products
        .joins(:canonical_product_aliases)
        .where(canonical_product_aliases: { normalized_name: normalized })
        .first
      return exact if exact

      by_name = @user.canonical_products.find_by(name: cleaned)
      return by_name if by_name

      stem_matches = @user.canonical_products
        .joins(:canonical_product_aliases)
        .where(canonical_product_aliases: { stem_signature: stem })
        .distinct
        .to_a
      best = best_fuzzy_match(cleaned, stem_matches)
      return best if best

      best_fuzzy_match(cleaned, @user.canonical_products.to_a)
    end

    private

    def create_canonical!(cleaned, preferred_name:)
      chosen_name = cleaned_name(preferred_name).presence
      chosen_name ||= ProductSubstitution.best_catalog_match(user: @user, raw_name: cleaned, min_score: 0.9)
      chosen_name ||= cleaned

      canonical = @user.canonical_products.find_or_create_by!(name: chosen_name)
      ensure_aliases!(canonical, [cleaned, chosen_name])
      canonical
    end

    def ensure_aliases!(canonical, names)
      names.compact.each do |name|
        cleaned = cleaned_name(name)
        next if cleaned.blank?

        canonical.canonical_product_aliases.find_or_create_by!(name: cleaned)
      end
    end

    def best_fuzzy_match(raw_name, candidates)
      return if candidates.blank?

      source_norm = ProductSubstitution.normalize_name(raw_name)
      source_tokens = normalized_tokens(raw_name)
      return if source_tokens.empty?

      best_candidate = nil
      best_score = MIN_FUZZY_SCORE

      candidates.each do |candidate|
        candidate_norm = ProductSubstitution.normalize_name(candidate.name)
        candidate_tokens = normalized_tokens(candidate.name)
        next if candidate_tokens.empty?

        token_score = ProductSubstitution.token_similarity(source_tokens, candidate_tokens)
        char_score = ProductSubstitution.char_similarity(source_norm, candidate_norm)
        score = (0.75 * token_score) + (0.25 * char_score)
        next if score < best_score

        best_score = score
        best_candidate = candidate
      end

      best_candidate
    end

    def normalized_tokens(text)
      ProductSubstitution.normalize_name(text)
        .split
        .map { |token| ProductSubstitution.normalize_polish_stem(token) }
        .reject(&:blank?)
    end

    def stem_signature(text)
      normalized_tokens(text).sort.join(' ')
    end

    def cleaned_name(text)
      ProductSubstitution.strip_quantity_from_name(text).to_s.strip
    end
  end
end
