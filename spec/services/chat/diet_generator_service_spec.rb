# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::DietGeneratorService do
  subject(:service) { described_class.new(diet) }

  let(:diet) do
    build(
      :diet,
      kcal_target: 1800,
      generation_prefs: { 'days_count' => 1, 'slots' => %w[breakfast lunch dinner] }
    )
  end
  let(:client) { instance_double(OpenAI::Client) }

  before do
    allow(service).to receive(:openai_client).and_return(client)
    allow(DietJsonValidator).to receive(:validate!).and_call_original
  end

  it 'requests a diet matching the requested day count and returns the parsed days array' do
    response_body = {
      'days' => [
        {
          'day' => 1,
          'meals' => [
            {
              'type' => 'breakfast',
              'name' => 'Owsianka',
              'ingredients' => [{ 'product' => 'Płatki owsiane', 'quantity' => '50g' }],
              'instructions' => 'Zagotuj płatki z mlekiem.',
              'nutrition' => { 'kcal' => 350, 'protein' => 12, 'fat' => 8, 'carbs' => 55 }
            },
            {
              'type' => 'lunch',
              'name' => 'Kurczak z ryżem',
              'ingredients' => [{ 'product' => 'Pierś z kurczaka', 'quantity' => '150g' }],
              'instructions' => 'Usmaż kurczaka, ugotuj ryż.',
              'nutrition' => { 'kcal' => 650, 'protein' => 45, 'fat' => 15, 'carbs' => 70 }
            },
            {
              'type' => 'dinner',
              'name' => 'Sałatka',
              'ingredients' => [{ 'product' => 'Sałata', 'quantity' => '100g' }],
              'instructions' => 'Wymieszaj składniki.',
              'nutrition' => { 'kcal' => 300, 'protein' => 10, 'fat' => 10, 'carbs' => 30 }
            }
          ]
        }
      ]
    }

    captured_params = nil
    allow(client).to receive(:chat) do |parameters:|
      captured_params = parameters
      { 'choices' => [{ 'message' => { 'content' => response_body.to_json } }] }
    end

    result = service.call

    expect(result).to eq(response_body['days'])
    expect(captured_params[:response_format][:json_schema][:schema]['properties']['days']['minItems']).to eq(1)
    expect(DietJsonValidator).to have_received(:validate!).with(result)
  end

  it 'raises when the generated JSON fails schema validation' do
    invalid_body = { 'days' => [{ 'day' => 1, 'meals' => [] }] } # meals empty violates minItems: 1

    allow(client).to receive(:chat).and_return(
      { 'choices' => [{ 'message' => { 'content' => invalid_body.to_json } }] }
    )

    expect { service.call }.to raise_error(DietJsonValidationError)
  end

  it 'asks the model for a category per ingredient, limited to the seeded categories' do
    create(:category, name: 'Warzywa')
    create(:category, name: 'Inne')
    schema = nil
    allow(client).to receive(:chat) do |parameters:|
      schema = parameters[:response_format][:json_schema][:schema]
      raise Faraday::BadRequestError, 'stop after capture'
    end

    expect { service.call }.to raise_error(RuntimeError)

    ingredient = schema.dig('properties', 'days', 'items', 'properties', 'meals', 'items',
                            'properties', 'ingredients', 'items')
    expect(ingredient['required']).to include('category')
    expect(ingredient.dig('properties', 'category', 'enum')).to contain_exactly('Warzywa', 'Inne')
  end
end
