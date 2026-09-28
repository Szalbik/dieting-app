# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::Strategies::NativePdf do
  subject(:strategy) do
    described_class.new('/tmp/diet.pdf', stats: stats, expected_meals_per_day: nil, model: 'gpt-5.1',
                                         reasoning_effort: 'low', concurrency: 2)
  end

  let(:stats) { Chat::Diet::ParsingPipeline::Stats.empty }
  let(:files) { instance_double(OpenAI::Files, upload: { 'id' => 'file-123' }, delete: { 'deleted' => true }) }
  let(:responses) { instance_double(OpenAI::Responses) }
  let(:client) { instance_double(OpenAI::Client, files: files, responses: responses) }
  let(:requests) { [] }

  def reply(json)
    { 'status' => 'completed',
      'output' => [{ 'type' => 'reasoning', 'summary' => [] },
                   { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => json.to_json }] }],
      'usage' => { 'input_tokens' => 500, 'output_tokens' => 50,
                   'input_tokens_details' => { 'cached_tokens' => 400 } } }
  end

  def day_json(day, meal_name)
    { day: day, meals: [{ type: 'breakfast', name: meal_name, ingredients: [{ product: 'jajka', quantity: '2 szt' }],
                          instructions: '', nutrition: { kcal: 200, protein: 12, fat: 14, carbs: 1 } }] }
  end

  before do
    allow(Chat::Diet::DayExtraction).to receive(:client).and_return(client)
    allow(responses).to receive(:create) do |parameters:|
      requests << parameters
      name = parameters.dig(:text, :format, :name)
      if name == 'diet_outline'
        reply(days: [{ day: 1, title: 'Poniedziałek', pages: [2] }, { day: 2, title: 'Wtorek', pages: [3] }])
      else
        day = parameters[:input][0][:content][1][:text][/"day" must be (\d+)/, 1].to_i
        reply(day_json(99, "Dzień #{day}")) # echoed day deliberately wrong
      end
    end
  end

  it 'uploads the PDF once, outlines it, extracts each day against the same file and deletes the upload' do
    days = strategy.call

    expect(days.map { |d| [d['day'], d['meals'][0]['name']] }).to eq([[1, 'Dzień 1'], [2, 'Dzień 2']])
    expect(files).to have_received(:upload).once.with(parameters: { file: '/tmp/diet.pdf', purpose: 'user_data' })
    expect(requests.size).to eq(3)
    expect(requests.map { |r| r[:input][0][:content][0] }).to all(eq(type: 'input_file', file_id: 'file-123'))
    expect(files).to have_received(:delete).with(id: 'file-123')
  end

  it 'sends the per-day schema with the category enum to every day call' do
    create(:category, name: 'Warzywa')

    strategy.call

    day_schemas = requests.select { |r| r.dig(:text, :format, :name) == 'diet_parsing_day' }
                          .map { |r| r.dig(:text, :format, :schema) }
    expect(day_schemas.size).to eq(2)
    expect(day_schemas).to all(satisfy do |schema|
      schema.dig('properties', 'meals', 'items', 'properties', 'ingredients', 'items', 'properties', 'category',
                 'enum') == ['Warzywa']
    end)
  end

  it 'passes reasoning effort without temperature for a reasoning model above "none"' do
    strategy.call

    expect(requests).to all(include(reasoning: { effort: 'low' }))
    expect(requests).to all(satisfy { |r| !r.key?(:temperature) })
  end

  it 'records usage from every call' do
    strategy.call

    expect(stats.to_h).to include(calls: 3, input_tokens: 1500, cached_tokens: 1200, output_tokens: 150,
                                  source: :native_pdf)
  end

  it 'still deletes the upload when extraction fails' do
    allow(responses).to receive(:create).and_raise(Faraday::BadRequestError.new('boom'))

    expect { strategy.call }.to raise_error(/OpenAI API error/)
    expect(files).to have_received(:delete).with(id: 'file-123')
  end

  it 'deletes the upload only after every in-flight day call has finished when one day fails' do
    allow(responses).to receive(:create) do |parameters:|
      if parameters.dig(:text, :format, :name) == 'diet_outline'
        next reply(days: [{ day: 1, title: 'A', pages: [1] }, { day: 2, title: 'B', pages: [2] }])
      end

      day = parameters[:input][0][:content][1][:text][/"day" must be (\d+)/, 1].to_i
      raise 'day 1 exploded' if day == 1

      sleep 0.02
      expect(files).not_to have_received(:delete)
      reply(day_json(2, 'B'))
    end

    expect { strategy.call }.to raise_error('day 1 exploded')
    expect(files).to have_received(:delete).with(id: 'file-123')
  end

  it 'rejects a bad outline before paying for day calls' do
    allow(responses).to receive(:create) do |parameters:|
      requests << parameters
      reply(days: [{ day: 1, title: 'A', pages: [1] }, { day: 1, title: 'A again', pages: [2] }])
    end

    expect { strategy.call }.to raise_error(/zduplikowane numery dni/)
    expect(requests.size).to eq(1)
    expect(files).to have_received(:delete).with(id: 'file-123')
  end

  it 'surfaces an incomplete response instead of a JSON error' do
    allow(responses).to receive(:create).and_return('status' => 'incomplete', 'output' => [],
                                                    'incomplete_details' => { 'reason' => 'max_output_tokens' })

    expect { strategy.call }.to raise_error(/incomplete: max_output_tokens/)
  end
end
