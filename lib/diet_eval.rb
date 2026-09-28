# frozen_string_literal: true

require_relative 'diet_eval/scorer'
require_relative 'diet_eval/report'

# Offline evaluation of the PDF -> diet parser on a corpus of real PDFs.
# Used by `bin/rails diet:benchmark` / `diet:golden:draft` and the tagged
# regression spec. Runs the production ParsingPipeline unchanged; parser knobs
# are swapped through config.x.openai for the duration of one run.
module DietEval
  CORPUS_DIR = Rails.root.join('spec/fixtures/diet_corpus')

  # USD per 1M tokens: [input, cached input, output]. Verify against
  # https://developers.openai.com/api/docs/pricing before trusting cost columns.
  PRICING = {
    'gpt-5.1' => [1.25, 0.125, 10.0],
    'gpt-5' => [1.25, 0.125, 10.0],
    'gpt-5-mini' => [0.25, 0.025, 2.0],
    'gpt-4.1' => [2.0, 0.5, 8.0]
  }.freeze

  KNOBS = {
    model: :diet_parsing_model,
    strategy: :diet_parsing_strategy,
    reasoning_effort: :diet_parsing_reasoning_effort
  }.freeze

  Entry = Struct.new(:slug, :dir, :golden, keyword_init: true) do
    def pdf_path
      File.expand_path(golden.fetch('pdf', 'diet.pdf'), dir)
    end

    def scanned?
      golden['scanned'] == true
    end

    def meals_per_day
      golden['meals_per_day']
    end
  end

  Run = Struct.new(:slug, :config, :days, :stats, :score, :cost, :error, keyword_init: true)

  module_function

  def entries
    Dir[CORPUS_DIR.join('*/golden.json')].sort.map do |path|
      Entry.new(slug: File.basename(File.dirname(path)), dir: File.dirname(path), golden: JSON.parse(File.read(path)))
    end
  end

  # One parse of one corpus PDF under one knob configuration. Never raises:
  # a failed parse is a data point (score 0), not a crash of the whole matrix.
  def run(entry, config = {})
    pipeline = Chat::Diet::ParsingPipeline.new(entry.pdf_path, expected_meals_per_day: entry.meals_per_day)
    days = with_config(config) { pipeline.call }
    score = Scorer.new(entry.golden).score(days)
    Run.new(slug: entry.slug, config: config, days: days, stats: pipeline.stats, score: score,
            cost: cost(config[:model] || current(:model), pipeline.stats))
  rescue StandardError => e
    Run.new(slug: entry.slug, config: config, stats: pipeline&.stats, score: { composite: 0.0 },
            cost: pipeline ? cost(config[:model] || current(:model), pipeline.stats) : 0.0,
            error: "#{e.class}: #{e.message}")
  end

  def cost(model, stats)
    input, cached, output = PRICING.fetch(model.to_s) { return nil }
    fresh = stats.input_tokens - stats.cached_tokens
    ((fresh * input) + (stats.cached_tokens * cached) + (stats.output_tokens * output)) / 1_000_000.0
  end

  def with_config(config)
    openai = Rails.application.config.x.openai
    previous = config.to_h { |knob, _| [knob, openai.public_send(KNOBS.fetch(knob))] }
    config.each { |knob, value| openai.public_send("#{KNOBS.fetch(knob)}=", value) }
    yield
  ensure
    previous&.each { |knob, value| openai.public_send("#{KNOBS.fetch(knob)}=", value) }
  end

  def current(knob)
    Rails.application.config.x.openai.public_send(KNOBS.fetch(knob))
  end

  # Pipeline output -> golden.json shape, for a human to correct.
  def golden_from(days, pdf:, meals_per_day: nil)
    {
      'pdf' => pdf,
      'scanned' => false,
      'meals_per_day' => meals_per_day,
      'days' => days.map do |day|
        {
          'day' => day['day'],
          'meals' => day['meals'].map do |meal|
            { 'type' => meal['type'], 'name' => meal['name'],
              'ingredients' => meal['ingredients'].map { |i| i['product'] },
              'kcal' => meal.dig('nutrition', 'kcal') }
          end
        }
      end
    }
  end
end
