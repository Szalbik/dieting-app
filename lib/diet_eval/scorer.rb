# frozen_string_literal: true

# Compares a parsed diet (the `days` array ParsingPipeline returns) against a
# hand-checked golden.json. "Correct" = what a user notices: right number of
# days and meals, every ingredient present, per-meal kcal within ±10%.
#
# Ingredients are searched across the whole day (not per meal) so recall
# measures extraction; meal alignment is already scored by meal_count_exact.
module DietEval
  class Scorer
    WEIGHTS = { day: 0.3, meal: 0.3, recall: 0.3, kcal: 0.1 }.freeze
    KCAL_TOLERANCE = 0.10
    JACCARD_MIN = 0.5

    def initialize(golden)
      @golden_days = Array(golden['days'])
    end

    def score(output_days)
      output_by_day = Array(output_days).index_by { |day| day['day'].to_i }

      day_ok = output_by_day.size == @golden_days.size
      meal = fraction(@golden_days.map { |g| output_meals(output_by_day, g).size == Array(g['meals']).size })
      found, missing = ingredient_hits(output_by_day)
      recall = fraction(found)
      kcal = fraction(kcal_hits(output_by_day))

      {
        day_count_exact: day_ok,
        meal_count_exact: meal,
        ingredient_recall: recall,
        kcal_within_10pct: kcal,
        composite: (100 * ((WEIGHTS[:day] * (day_ok ? 1 : 0)) + (WEIGHTS[:meal] * meal) +
                           (WEIGHTS[:recall] * recall) + (WEIGHTS[:kcal] * kcal))).round(1),
        missing_ingredients: missing
      }
    end

    private

    def output_meals(output_by_day, golden_day)
      Array(output_by_day[golden_day['day'].to_i]&.dig('meals'))
    end

    def ingredient_hits(output_by_day)
      missing = []
      hits = @golden_days.flat_map do |g|
        names = output_meals(output_by_day, g).flat_map do |m|
          Array(m['ingredients']).map do |i|
            normalize(i['product'])
          end
        end
        Array(g['meals']).flat_map { |m| Array(m['ingredients']) }.map do |ingredient|
          next true if names.any? { |name| same_ingredient?(normalize(ingredient), name) }

          missing << "day #{g['day']}: #{ingredient}"
          false
        end
      end
      [hits, missing]
    end

    def kcal_hits(output_by_day)
      @golden_days.flat_map do |g|
        meals = output_meals(output_by_day, g)
        Array(g['meals']).each_with_index.map do |golden_meal, index|
          expected = golden_meal['kcal']
          next if expected.nil? # meals without a kcal in the PDF aren't scored

          actual = meals[index]&.dig('nutrition', 'kcal')
          !actual.nil? && (actual.to_f - expected.to_f).abs <= (KCAL_TOLERANCE * expected.to_f) + 1e-9
        end.compact
      end
    end

    def same_ingredient?(expected, actual)
      return false if expected.empty? || actual.empty?
      return true if actual.include?(expected) || expected.include?(actual)

      a = expected.split
      b = actual.split
      (a & b).size.fdiv((a | b).size) >= JACCARD_MIN
    end

    def normalize(text)
      I18n.transliterate(text.to_s.downcase).gsub(/[^a-z0-9]+/, ' ').squish
    end

    # Empty denominators mean "nothing to check" -> full marks, not a penalty.
    def fraction(bools)
      return 1.0 if bools.empty?

      bools.count(true).fdiv(bools.size).round(4)
    end
  end
end
