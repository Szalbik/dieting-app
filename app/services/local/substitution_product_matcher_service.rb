# frozen_string_literal: true

module Local
  class SubstitutionProductMatcherService
    STOPWORDS = %w[
      swiezy swieza swieze
      naturalny naturalnego naturalna
      tlusty tlusta tluszczu
      konserwowy konserwowa konserwowej
      fileta filet
      procent
    ].freeze

    SUFFIXES = %w[
      owego owej owych
      ami ach em ie
      ow a u y i e ę ą
    ].freeze

    def initialize(source_products:, diet_product_names:)
      @source_products = source_products.uniq
      @diet_product_names = diet_product_names.uniq
    end

    def call
      @source_products.map do |source|
        matches = scored_matches_for(source)
        {
          'source_product' => source,
          'matches' => matches.map { |name, score| { 'name' => name, 'score' => score } },
        }
      end
    end

    private

    def scored_matches_for(source)
      source_tokens = normalized_tokens(source)
      source_norm = source_tokens.join(' ')
      return [] if source_tokens.empty?

      scored = @diet_product_names.map do |candidate|
        candidate_tokens = normalized_tokens(candidate)
        next if candidate_tokens.empty?

        candidate_norm = candidate_tokens.join(' ')
        token_score = token_similarity(source_tokens, candidate_tokens)
        char_score = char_similarity(source_norm, candidate_norm)
        score = (0.72 * token_score) + (0.28 * char_score)
        common = source_tokens & candidate_tokens

        # Single-product sources (e.g. "ananasa") should still match extended labels
        # like "ananas z puszki" when core token is clearly present.
        if source_tokens.size == 1
          core = source_tokens.first
          if core.length >= 5 && candidate_tokens.any? { |token| similar_token?(core, token) }
            score = [score, 0.72].max
            common = [core]
          end
        end

        next unless score >= 0.58
        next if common.empty? && score < 0.9

        [candidate, score.round(4)]
      end.compact

      scored.sort_by { |_name, score| -score }.first(3)
    end

    def normalized_tokens(text)
      normalized = I18n.transliterate(text.to_s)
        .downcase
        .gsub(/[^a-z0-9\s]/, ' ')
        .squeeze(' ')
        .strip

      normalized.split
        .map { |token| lemma(token) }
        .reject { |token| token.blank? || STOPWORDS.include?(token) || token.length < 2 }
    end

    def lemma(token)
      return token if token.length < 4

      reduced = token.dup
      SUFFIXES.each do |suffix|
        next unless reduced.end_with?(suffix)
        next if reduced.length - suffix.length < 3

        reduced = reduced.delete_suffix(suffix)
        break
      end

      reduced
    end

    def token_similarity(a_tokens, b_tokens)
      a = a_tokens.uniq
      b = b_tokens.uniq
      return 0.0 if a.empty? || b.empty?

      matched = a.count do |left|
        b.any? { |right| similar_token?(left, right) }
      end

      matched.to_f / [a.size, b.size].max
    end

    def similar_token?(left, right)
      return true if left == right
      return false if left.length < 4 || right.length < 4

      left.start_with?(right) || right.start_with?(left)
    end

    def char_similarity(a, b)
      max_len = [a.length, b.length].max
      return 1.0 if max_len.zero?

      1.0 - (levenshtein_distance(a, b).to_f / max_len)
    end

    def levenshtein_distance(a, b)
      m = a.length
      n = b.length
      return n if m.zero?
      return m if n.zero?

      prev = (0..n).to_a
      curr = Array.new(n + 1, 0)

      (1..m).each do |i|
        curr[0] = i
        (1..n).each do |j|
          cost = a[i - 1] == b[j - 1] ? 0 : 1
          curr[j] = [
            curr[j - 1] + 1,
            prev[j] + 1,
            prev[j - 1] + cost,
          ].min
        end
        prev, curr = curr, prev
      end

      prev[n]
    end
  end
end
