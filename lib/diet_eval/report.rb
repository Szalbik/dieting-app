# frozen_string_literal: true

module DietEval
  # Markdown tables for a list of DietEval::Run: one row per PDF x config,
  # then one aggregate row per config (what the pick rule reads).
  class Report
    def initialize(runs)
      @runs = runs
    end

    def to_markdown
      [per_pdf, '', aggregate].join("\n")
    end

    private

    def per_pdf
      rows = @runs.map do |run|
        s = run.score
        [run.slug, label(run), fmt(s[:composite]), fmt(s[:ingredient_recall]), fmt(s[:kcal_within_10pct]),
         s[:day_count_exact].nil? ? '-' : s[:day_count_exact], fmt(s[:meal_count_exact]),
         fmt(run.stats&.seconds), money(run.cost), run.error.to_s.truncate(80)]
      end
      table(%w[pdf config composite recall kcal days_ok meals_ok seconds cost error], rows)
    end

    def aggregate
      rows = @runs.group_by { |run| label(run) }.map do |config, runs|
        seconds = runs.filter_map { |r| r.stats&.seconds }.sort
        costs = runs.filter_map(&:cost)
        [config, fmt(mean(runs.map { |r| r.score[:composite] })), fmt(percentile(seconds, 0.5)),
         fmt(percentile(seconds, 0.95)), money(costs.empty? ? nil : mean(costs)), runs.count(&:error)]
      end
      table(%w[config mean_composite p50_s p95_s mean_cost failures], rows.sort_by { |r| -r[1].to_f })
    end

    def label(run)
      run.config.values.join('/').presence || 'default'
    end

    def table(header, rows)
      (["| #{header.join(' | ')} |", "|#{'---|' * header.size}"] + rows.map { |r| "| #{r.join(' | ')} |" }).join("\n")
    end

    def mean(values)
      values.sum.fdiv(values.size)
    end

    # Nearest-rank percentile; small corpora make interpolation meaningless.
    def percentile(sorted, pct)
      return nil if sorted.empty?

      sorted[[(pct * sorted.size).ceil - 1, 0].max]
    end

    def fmt(value)
      value.nil? ? '-' : format('%.2f', value)
    end

    def money(value)
      value.nil? ? '-' : format('$%.3f', value)
    end
  end
end
