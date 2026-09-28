# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::ParsingPipeline do
  subject(:pipeline) { described_class.new('/tmp/example.pdf', expected_meals_per_day: 2) }

  let(:days) do
    [
      { 'day' => 2, 'meals' => [{ 'type' => 'dinner', 'name' => 'B', 'ingredients' => [], 'instructions' => '',
                                  'nutrition' => { 'kcal' => 1, 'protein' => 1, 'fat' => 1, 'carbs' => 1 } }] },
      { 'day' => 1, 'meals' => [{ 'type' => 'breakfast', 'name' => 'A', 'ingredients' => [], 'instructions' => '',
                                  'nutrition' => { 'kcal' => 1, 'protein' => 1, 'fat' => 1, 'carbs' => 1 } }] }
    ]
  end
  let(:strategy) { instance_double(Chat::Diet::Strategies::NativePdf, call: days) }
  let(:openai) { Rails.application.config.x.openai }

  around do |example|
    previous = openai.diet_parsing_strategy
    openai.diet_parsing_strategy = 'native_pdf'
    example.run
  ensure
    openai.diet_parsing_strategy = previous
  end

  before do
    allow(Chat::Diet::Strategies::NativePdf).to receive(:new).and_return(strategy)
    allow(DietJsonValidator).to receive(:validate!)
    allow(Chat::DietMealConsolidator).to receive(:new).and_call_original
  end

  it 'runs the configured strategy with the parser knobs from config' do
    pipeline.call

    expect(Chat::Diet::Strategies::NativePdf).to have_received(:new).with(
      '/tmp/example.pdf', stats: pipeline.stats, expected_meals_per_day: 2, model: openai.diet_parsing_model,
                          reasoning_effort: openai.diet_parsing_reasoning_effort,
                          concurrency: openai.diet_parsing_concurrency
    )
  end

  it 'sorts days, consolidates meals and validates the result' do
    result = pipeline.call

    expect(result.map { |d| d['day'] }).to eq([1, 2])
    expect(Chat::DietMealConsolidator).to have_received(:new).with(result, expected_meals_per_day: 2)
    expect(DietJsonValidator).to have_received(:validate!).with(result)
    expect(pipeline.stats.seconds).to be >= 0
  end

  it 'rejects an unknown strategy name' do
    openai.diet_parsing_strategy = 'nope'

    expect { pipeline.call }.to raise_error(ArgumentError, /Unknown diet parsing strategy/)
  end

  describe Chat::Diet::ParsingPipeline::Stats do
    it 'sums Chat Completions and Responses usage shapes' do
      stats = described_class.empty
      stats.record('prompt_tokens' => 1000, 'completion_tokens' => 200,
                   'prompt_tokens_details' => { 'cached_tokens' => 100 })
      stats.record('input_tokens' => 500, 'output_tokens' => 50, 'input_tokens_details' => { 'cached_tokens' => 400 })

      expect(stats.to_h).to include(calls: 2, input_tokens: 1500, cached_tokens: 500, output_tokens: 250)
    end
  end
end
