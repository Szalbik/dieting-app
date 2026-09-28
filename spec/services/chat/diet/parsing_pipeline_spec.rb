# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::ParsingPipeline do
  subject(:pipeline) { described_class.new('/tmp/example.pdf', expected_meals_per_day: 2) }

  let(:page_1) do
    PdfTextExtractor::Page.new(
      page_number: 1,
      text: <<~TEXT
        ## Zestaw 1

        ## 1) Śniadanie
        Kanapki
        -chleb razowy -2kromki (70g)
      TEXT
    )
  end
  let(:page_2) do
    PdfTextExtractor::Page.new(
      page_number: 2,
      text: <<~TEXT
        ## Zestaw 2

        ## 1) Obiad
        Sałatka z kurczakiem
        -mięso z piersi kurczaka (150g)
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
    allow(Chat::Diet::MarkdownExtractor).to receive(:new).and_return(instance_double(Chat::Diet::MarkdownExtractor,
                                                                                     extract: extraction))
    allow(Chat::Diet::PageImageSet).to receive(:new).and_return(image_set)
    allow(pipeline).to receive(:openai_client).and_return(client)
    allow(DietJsonValidator).to receive(:validate!)
    allow(Chat::DietMealConsolidator).to receive(:new).and_call_original
  end

  it 'makes one OpenAI call per day and assembles the final parsed_json' do
    calls = []
    responses = [
      {
        day: 1,
        meals: [
          {
            type: 'breakfast',
            name: 'Kanapki',
            ingredients: [{ product: 'chleb razowy', quantity: '2 kromki' }],
            instructions: '',
            nutrition: { kcal: 200, protein: 8, fat: 4, carbs: 30 }
          }
        ]
      },
      {
        day: 1, # deliberately wrong - pipeline must override with chunk.day
        meals: [
          {
            type: 'dinner',
            name: 'Sałatka z kurczakiem',
            ingredients: [{ product: 'mięso z piersi kurczaka', quantity: '150g' }],
            instructions: '',
            nutrition: { kcal: 450, protein: 32, fat: 20, carbs: 18 }
          }
        ]
      }
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
                                 'nutrition' => { 'kcal' => 200, 'protein' => 8, 'fat' => 4, 'carbs' => 30 }
                               }
                             ]
                           },
                           {
                             'day' => 2,
                             'meals' => [
                               {
                                 'type' => 'dinner',
                                 'name' => 'Sałatka z kurczakiem',
                                 'ingredients' => [{ 'product' => 'mięso z piersi kurczaka', 'quantity' => '150g' }],
                                 'instructions' => '',
                                 'nutrition' => { 'kcal' => 450, 'protein' => 32, 'fat' => 20, 'carbs' => 18 }
                               }
                             ]
                           }
                         ])

    expect(calls.size).to eq(2)
    expect(Chat::DietMealConsolidator).to have_received(:new).with(result, expected_meals_per_day: 2)
    expect(DietJsonValidator).to have_received(:validate!).with(result)
    expect(calls.map { |call| call[:model] }).to eq([
                                                      Rails.application.config.x.openai.diet_parsing_model,
                                                      Rails.application.config.x.openai.diet_parsing_model
                                                    ])
  end

  it 'attaches only that day\'s page images, and only in OCR mode' do
    responses = [
      { day: 1,
        meals: [{ type: 'breakfast', name: 'Kanapki', ingredients: [], instructions: '',
                  nutrition: { kcal: 1, protein: 1, fat: 1, carbs: 1 } }] },
      { day: 2,
        meals: [{ type: 'dinner', name: 'Sałatka', ingredients: [], instructions: '',
                  nutrition: { kcal: 1, protein: 1, fat: 1, carbs: 1 } }] }
    ]

    allow(client).to receive(:chat) do |**|
      { 'choices' => [{ 'message' => { 'content' => responses.shift.to_json } }] }
    end

    pipeline.call

    expect(image_set).to have_received(:image_parts_for).with([1]).at_least(:once)
    expect(image_set).to have_received(:image_parts_for).with([2]).at_least(:once)
  end

  context 'when extraction did not require OCR' do
    let(:source) { :markdown }

    it 'sends plain text without page images' do
      responses = [
        { day: 1,
          meals: [{ type: 'breakfast', name: 'Kanapki', ingredients: [], instructions: '',
                    nutrition: { kcal: 1, protein: 1, fat: 1, carbs: 1 } }] },
        { day: 2,
          meals: [{ type: 'dinner', name: 'Sałatka', ingredients: [], instructions: '',
                    nutrition: { kcal: 1, protein: 1, fat: 1, carbs: 1 } }] }
      ]
      captured_messages = []

      allow(client).to receive(:chat) do |parameters:|
        captured_messages << parameters[:messages].last[:content]
        { 'choices' => [{ 'message' => { 'content' => responses.shift.to_json } }] }
      end

      pipeline.call

      expect(image_set).not_to have_received(:image_parts_for)
      expect(captured_messages).to all(be_a(String))
    end
  end

  it 'asks the model for a category per ingredient, limited to the seeded categories' do
    create(:category, name: 'Warzywa')
    create(:category, name: 'Inne')
    schemas = []
    allow(client).to receive(:chat) do |parameters:|
      schemas << parameters[:response_format][:json_schema][:schema]
      { 'choices' => [{ 'message' => { 'content' => { day: 1, meals: [] }.to_json } }] }
    end

    pipeline.call

    ingredient = schemas.first.dig('properties', 'meals', 'items', 'properties', 'ingredients', 'items')
    expect(ingredient['required']).to include('category')
    expect(ingredient.dig('properties', 'category', 'enum')).to contain_exactly('Warzywa', 'Inne')
  end
end
