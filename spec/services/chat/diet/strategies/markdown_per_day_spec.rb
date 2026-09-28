# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::Strategies::MarkdownPerDay do
  subject(:strategy) do
    described_class.new('/tmp/example.pdf', stats: stats, expected_meals_per_day: 2, model: model,
                                            reasoning_effort: effort, concurrency: 4)
  end

  let(:stats) { Chat::Diet::ParsingPipeline::Stats.empty }
  let(:model) { 'gpt-5.1' }
  let(:effort) { 'none' }
  let(:source) { :markdown }
  let(:pages) do
    [
      PdfTextExtractor::Page.new(page_number: 1, text: "## Zestaw 1\n\n## 1) Śniadanie\nKanapki\n-chleb razowy (70g)"),
      PdfTextExtractor::Page.new(page_number: 2, text: "## Zestaw 2\n\n## 1) Obiad\nSałatka\n-pierś z kurczaka (150g)")
    ]
  end
  let(:client) { instance_double(OpenAI::Client) }
  let(:image_set) do
    instance_double(Chat::Diet::PageImageSet, cleanup: true,
                                              image_parts_for: [{ type: 'image_url', image_url: { url: 'data:x' } }])
  end
  let(:calls) { [] }

  def meal(name)
    { type: 'breakfast', name: name, ingredients: [], instructions: '',
      nutrition: { kcal: 1, protein: 1, fat: 1, carbs: 1 } }
  end

  before do
    extraction = PdfTextExtractor::Result.new(text: pages.map(&:text).join("\n\n"), page_count: pages.size,
                                              source: source, pages: pages)
    allow(Chat::Diet::MarkdownExtractor).to receive(:new).and_return(instance_double(Chat::Diet::MarkdownExtractor,
                                                                                     extract: extraction))
    allow(Chat::Diet::PageImageSet).to receive(:new).and_return(image_set)
    allow(Chat::Diet::DayExtraction).to receive(:client).and_return(client)
    allow(client).to receive(:chat) do |parameters:|
      calls << parameters
      text = Array(parameters[:messages].last[:content]).then { |c| c.first.is_a?(Hash) ? c.first[:text] : c.first }
      body = if parameters.dig(:response_format, :json_schema, :name) == 'diet_day_headings'
               { days: [{ day: 1, heading: 'Poniedziałek' }, { day: 2, heading: '**Wtorek**' }] }
             else
               { day: 99, meals: [meal(text[/(Kanapki|Sałatka|Omlet|Jajecznica)/, 1] || 'X')] }
             end
      { 'choices' => [{ 'message' => { 'content' => body.to_json } }] }
    end
  end

  it 'makes one call per day in document order, overriding the echoed day' do
    days = strategy.call

    expect(days.map { |d| [d['day'], d['meals'][0]['name']] }).to eq([[1, 'Kanapki'], [2, 'Sałatka']])
    expect(calls.size).to eq(2)
    expect(image_set).not_to have_received(:image_parts_for)
  end

  it 'keeps temperature 0.2 at reasoning effort "none" (pre-strategy baseline)' do
    strategy.call

    expect(calls).to all(include(temperature: 0.2, reasoning_effort: 'none', model: 'gpt-5.1'))
  end

  context 'with a reasoning effort above none' do
    let(:effort) { 'medium' }

    it 'drops temperature' do
      strategy.call

      expect(calls).to all(include(reasoning_effort: 'medium'))
      expect(calls).to all(satisfy { |c| !c.key?(:temperature) })
    end
  end

  context 'with a non-reasoning model' do
    let(:model) { 'gpt-4.1' }

    it 'sends temperature and no reasoning_effort' do
      strategy.call

      expect(calls).to all(include(temperature: 0.2))
      expect(calls).to all(satisfy { |c| !c.key?(:reasoning_effort) })
    end
  end

  context 'with OCR-extracted text' do
    let(:source) { :ocr }

    it "attaches that day's page images" do
      strategy.call

      expect(image_set).to have_received(:image_parts_for).with([1])
      expect(image_set).to have_received(:image_parts_for).with([2])
    end
  end

  context 'when a multi-page PDF has no Dzień/Zestaw headings' do
    let(:pages) do
      [
        PdfTextExtractor::Page.new(page_number: 1, text: "# Poniedziałek\n\n## Śniadanie\nOmlet"),
        PdfTextExtractor::Page.new(page_number: 2, text: "# **Wtorek**\n\n## Śniadanie\nJajecznica")
      ]
    end

    it 'asks the model for day headings and splits on them' do
      days = strategy.call

      expect(calls.first.dig(:response_format, :json_schema, :name)).to eq('diet_day_headings')
      expect(days.map { |d| [d['day'], d['meals'][0]['name']] }).to eq([[1, 'Omlet'], [2, 'Jajecznica']])
    end
  end

  context 'when a single-page PDF has no headings' do
    let(:pages) { [PdfTextExtractor::Page.new(page_number: 1, text: "## Śniadanie\nOmlet")] }

    it 'parses it as one day without asking for headings' do
      days = strategy.call

      expect(days.map { |d| d['day'] }).to eq([1])
      expect(calls.map { |c| c.dig(:response_format, :json_schema, :name) }).to eq(['diet_parsing_day'])
    end
  end
end
