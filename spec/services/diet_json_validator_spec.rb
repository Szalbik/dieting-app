# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietJsonValidator do
  let(:valid_day) do
    {
      'day' => 1,
      'meals' => [
        {
          'type' => 'breakfast',
          'name' => 'Owsianka',
          'ingredients' => [
            { 'product' => 'Płatki owsiane', 'quantity' => '50g' },
          ],
          'instructions' => 'Zalej mlekiem.',
          'nutrition' => {
            'kcal' => 300.0,
            'protein' => 12.0,
            'fat' => 6.0,
            'carbs' => 48.0,
          },
        },
      ],
    }
  end

  describe '.validate' do
    it 'returns valid for data matching the diet parser schema' do
      result = described_class.validate([valid_day])
      expect(result[:valid]).to be true
      expect(result[:errors]).to be_empty
    end

    it 'returns invalid when required meal fields are missing' do
      bad = [{ 'day' => 1, 'meals' => [{ 'type' => 'breakfast', 'name' => 'X' }] }]
      result = described_class.validate(bad)
      expect(result[:valid]).to be false
      expect(result[:errors]).not_to be_empty
    end
  end

  describe '.validate!' do
    it 'returns the payload when valid' do
      payload = [valid_day]
      expect(described_class.validate!(payload)).to eq(payload)
    end

    it 'raises DietJsonValidationError when invalid' do
      expect do
        described_class.validate!([{ 'day' => 1, 'meals' => [] }])
      end.to raise_error(DietJsonValidationError) do |err|
        expect(err.errors).to be_a(Array)
      end
    end
  end
end
