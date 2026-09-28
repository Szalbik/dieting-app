# frozen_string_literal: true

# PDF -> validated `days` array. How the PDF reaches the model is a strategy
# (Chat::Diet::Strategies, picked by config.x.openai.diet_parsing_strategy);
# consolidation and schema validation are shared by every strategy.
class Chat::Diet::ParsingPipeline
  # Token/time accounting read by the diet:benchmark task; production ignores it.
  Stats = Struct.new(:calls, :input_tokens, :cached_tokens, :output_tokens, :seconds, :source, keyword_init: true) do
    def self.empty
      new(calls: 0, input_tokens: 0, cached_tokens: 0, output_tokens: 0, seconds: 0.0, source: nil)
    end

    # Accepts both Chat Completions (prompt/completion_tokens) and Responses
    # (input/output_tokens) usage shapes.
    def record(usage)
      usage ||= {}
      self.calls += 1
      self.input_tokens += (usage['prompt_tokens'] || usage['input_tokens']).to_i
      self.output_tokens += (usage['completion_tokens'] || usage['output_tokens']).to_i
      details = usage['prompt_tokens_details'] || usage['input_tokens_details'] || {}
      self.cached_tokens += details['cached_tokens'].to_i
    end
  end

  attr_reader :stats

  def initialize(file_path, expected_meals_per_day: nil)
    @file_path = file_path
    @expected_meals_per_day = expected_meals_per_day
    @stats = Stats.empty
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    days = strategy.call.sort_by { |day| day['day'] }
    days = Chat::DietMealConsolidator.new(days, expected_meals_per_day: @expected_meals_per_day).call

    DietJsonValidator.validate!(days)
    days
  ensure
    @stats.seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started if started
  end

  private

  def strategy
    openai = Rails.application.config.x.openai
    Chat::Diet::Strategies.for(openai.diet_parsing_strategy).new(
      @file_path,
      stats: @stats,
      expected_meals_per_day: @expected_meals_per_day,
      model: openai.diet_parsing_model,
      reasoning_effort: openai.diet_parsing_reasoning_effort,
      concurrency: openai.diet_parsing_concurrency
    )
  end
end
