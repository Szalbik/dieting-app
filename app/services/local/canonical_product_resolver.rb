# frozen_string_literal: true

module Local
  class CanonicalProductResolver
    MIN_FUZZY_SCORE = 0.9

    Result = Data.define(:canonical_product, :match_type, :confidence)

    def initialize(user:)
      @user = user
      @normalizer = ShoppingList::ProductNormalizer.new
    end

    def call(raw_name:, preferred_name: nil)
      cleaned = cleaned_name(raw_name)
      return if @user.blank? || cleaned.blank?

      result = resolve_existing(raw_name: cleaned)
      if result.nil?
        canonical = create_canonical!(cleaned, preferred_name: preferred_name)
        result = Result.new(canonical_product: canonical, match_type: :new, confidence: 0.0)
      end

      ensure_aliases!(result.canonical_product, [raw_name, preferred_name, cleaned])
      promote_better_canonical_name!(result.canonical_product, [preferred_name, raw_name, cleaned])
      result
    end

    def call_for_canonical(raw_name:, preferred_name: nil)
      call(raw_name: raw_name, preferred_name: preferred_name)&.canonical_product
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
      return Result.new(canonical_product: exact, match_type: :exact_normalized, confidence: 1.0) if exact

      by_name = @user.canonical_products.find_by(name: cleaned)
      return Result.new(canonical_product: by_name, match_type: :exact_name, confidence: 1.0) if by_name

      stem_matches = @user.canonical_products
        .joins(:canonical_product_aliases)
        .where(canonical_product_aliases: { stem_signature: stem })
        .distinct
        .to_a
      stem_result = best_fuzzy_match(cleaned, stem_matches)
      if stem_result
        return Result.new(
          canonical_product: stem_result[:candidate],
          match_type: :stem,
          confidence: 0.95
        )
      end

      fuzzy_result = best_fuzzy_match(cleaned, @user.canonical_products.to_a)
      if fuzzy_result
        return Result.new(
          canonical_product: fuzzy_result[:candidate],
          match_type: :fuzzy,
          confidence: fuzzy_result[:score]
        )
      end

      nil
    end

    private

    def create_canonical!(cleaned, preferred_name:)
      chosen_name = choose_better_name(nil, cleaned_name(preferred_name).presence)
      chosen_name ||= ProductSubstitution.best_catalog_match(user: @user, raw_name: cleaned, min_score: 0.9)
      chosen_name = choose_better_name(chosen_name, cleaned)
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

      best_candidate ? { candidate: best_candidate, score: best_score } : nil
    end

    def normalized_tokens(text)
      @normalizer.normalized_tokens(text)
    end

    def stem_signature(text)
      @normalizer.call(raw_name: text)[:key]
    end

    def cleaned_name(text)
      @normalizer.cleaned_name(text)
    end

    def promote_better_canonical_name!(canonical, names)
      better_name = names.compact.reduce(canonical.name) do |current, candidate|
        choose_better_name(current, cleaned_name(candidate))
      end
      return if better_name.blank? || better_name == canonical.name

      canonical.update!(name: better_name)
    end

    def choose_better_name(current_name, candidate_name)
      current = cleaned_name(current_name)
      candidate = cleaned_name(candidate_name)
      return current if candidate.blank?
      return candidate if current.blank?

      current_canonical = @normalizer.canonical_form?(current)
      candidate_canonical = @normalizer.canonical_form?(candidate)
      return candidate if candidate_canonical && !current_canonical
      return current if current_canonical && !candidate_canonical
      return candidate if candidate.length < current.length

      current
    end
  end
end
