# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::ParsingPipeline do
  subject(:pipeline) { described_class.new('/tmp/example.pdf', expected_meals_per_day: 4) }

  let(:page_1) do
    PdfTextExtractor::Page.new(
      page_number: 1,
      text: <<~TEXT
        Zestaw 1

        1) Śniadanie
        Kanapki
        -chleb razowy -2kromki (70g)
      TEXT
    )
  end
  let(:page_2) do
    PdfTextExtractor::Page.new(
      page_number: 2,
      text: <<~TEXT
        2) Obiad
        Sałatka z kurczakiem
        -mięso z piersi kurczaka (150g)
        Dressing:
        -oliwa z oliwek -1łyżka (10ml)
        Sposób wykonania:
        1. Wymieszaj.
      TEXT
    )
  end
  let(:extraction) do
    PdfTextExtractor::Result.new(
      text: [page_1.text, page_2.text].join("\n\n"),
      page_count: 2,
      source: source,
      pages: [page_1, page_2]
    )
  end
  let(:source) { :ocr }
  let(:client) { instance_double(OpenAI::Client) }
  let(:image_set) { instance_double(Chat::Diet::PageImageSet, image_parts_for: [{ type: 'image_url', image_url: { url: 'data:image/png;base64,abc', detail: 'high' } }], cleanup: true) }

  before do
    allow(PdfTextExtractor).to receive(:new).and_return(instance_double(PdfTextExtractor, extract: extraction))
    allow(Chat::Diet::PageImageSet).to receive(:new).and_return(image_set)
    allow(pipeline).to receive(:openai_client).and_return(client)
    allow(DietJsonValidator).to receive(:validate!)
    allow(Chat::DietMealConsolidator).to receive(:new).and_call_original
  end

  it 'assembles final parsed_json from staged OpenAI responses and validates at the end' do
    calls = []
    responses = [
      { type: 'breakfast', name: 'Kanapki' },
      { ingredients: [{ product: 'chleb razowy', quantity: '2 kromki' }] },
      { instructions: '', nutrition: { kcal: 200, protein: 8, fat: 4, carbs: 30 } },
      { type: 'dinner', name: 'Sałatka z kurczakiem' },
      { ingredients: [{ product: 'mięso z piersi kurczaka', quantity: '150g' }, { product: 'oliwa z oliwek', quantity: '1 łyżka' }] },
      { instructions: "1. Wymieszaj.", nutrition: { kcal: 450, protein: 32, fat: 20, carbs: 18 } },
    ]

    allow(client).to receive(:chat) do |parameters:|
      calls << parameters
      { 'choices' => [{ 'message' => { 'content' => responses.shift.to_json } }] }
    end

    result = pipeline.call

    expect(result).to eq([
      {
        'day' => 1,
        'meals' => [
          {
            'type' => 'breakfast',
            'name' => 'Kanapki',
            'ingredients' => [{ 'product' => 'chleb razowy', 'quantity' => '2 kromki' }],
            'instructions' => '',
            'nutrition' => { 'kcal' => 200, 'protein' => 8, 'fat' => 4, 'carbs' => 30 },
          },
          {
            'type' => 'dinner',
            'name' => 'Sałatka z kurczakiem',
            'ingredients' => [
              { 'product' => 'mięso z piersi kurczaka', 'quantity' => '150g' },
              { 'product' => 'oliwa z oliwek', 'quantity' => '1 łyżka' },
            ],
            'instructions' => "1. Wymieszaj.",
            'nutrition' => { 'kcal' => 450, 'protein' => 32, 'fat' => 20, 'carbs' => 18 },
          },
        ],
      },
    ])

    expect(Chat::DietMealConsolidator).to have_received(:new).with(result, expected_meals_per_day: 4)
    expect(DietJsonValidator).to have_received(:validate!).with(result)
    expect(calls).to all(include(:messages))
    expect(calls.map { |call| call[:model] }).to eq([
      Rails.application.config.x.openai.diet_parsing_models.metadata,
      Rails.application.config.x.openai.diet_parsing_models.ingredients,
      Rails.application.config.x.openai.diet_parsing_models.instructions_nutrition,
      Rails.application.config.x.openai.diet_parsing_models.metadata,
      Rails.application.config.x.openai.diet_parsing_models.ingredients,
      Rails.application.config.x.openai.diet_parsing_models.instructions_nutrition,
    ])
  end

  it 'sends only segment-specific page images in OCR mode' do
    captured_messages = []
    responses = [
      { type: 'breakfast', name: 'Kanapki' },
      { ingredients: [{ product: 'chleb razowy', quantity: '2 kromki' }] },
      { instructions: '', nutrition: { kcal: 200, protein: 8, fat: 4, carbs: 30 } },
      { type: 'dinner', name: 'Sałatka z kurczakiem' },
      { ingredients: [{ product: 'mięso z piersi kurczaka', quantity: '150g' }] },
      { instructions: '1. Wymieszaj.', nutrition: { kcal: 450, protein: 32, fat: 20, carbs: 18 } },
    ]

    allow(client).to receive(:chat) do |parameters:|
      captured_messages << parameters[:messages].last[:content]
      { 'choices' => [{ 'message' => { 'content' => responses.shift.to_json } }] }
    end

    pipeline.call

    expect(image_set).to have_received(:image_parts_for).with([1]).at_least(:once)
    expect(image_set).to have_received(:image_parts_for).with([2]).at_least(:once)
    expect(captured_messages.first).to be_an(Array)
    expect(captured_messages.first.first[:text]).to include('attached page images')
  end
end
