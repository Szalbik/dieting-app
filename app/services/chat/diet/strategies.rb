# frozen_string_literal: true

# How a PDF reaches the model. Each strategy takes
#   .new(file_path, stats:, expected_meals_per_day:, model:, reasoning_effort:, concurrency:)
# and #call returns the `days` array (DayExtraction::DAY_SCHEMA per day),
# recording OpenAI usage into `stats`. Picked by config.x.openai.diet_parsing_strategy.
module Chat::Diet::Strategies
  NAMES = {
    'markdown_per_day' => 'Chat::Diet::Strategies::MarkdownPerDay',
    'native_pdf' => 'Chat::Diet::Strategies::NativePdf',
  }.freeze

  def self.for(name)
    NAMES.fetch(name.to_s) { raise ArgumentError, "Unknown diet parsing strategy: #{name.inspect}" }.constantize
  end
end
