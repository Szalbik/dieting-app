# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::MealMacroEstimatorService do
  subject(:service) do
    described_class.new(
      name: 'Owsianka',
      ingredients: [{ 'name' => 'Płatki owsiane', 'amount' => 50.0, 'unit' => 'g' }]
    )
  end

  let(:client) { instance_double(OpenAI::Client) }

  before { allow(service).to receive(:openai_client).and_return(client) }

  it 'returns the estimated macros parsed from the structured response' do
    macros = { 'kcal' => 350, 'protein' => 12.0, 'fat' => 8.0, 'carbs' => 55.0 }
    allow(client).to receive(:chat).and_return(
      { 'choices' => [{ 'message' => { 'content' => macros.to_json } }] }
    )

    expect(service.call).to eq(macros)
  end
end
