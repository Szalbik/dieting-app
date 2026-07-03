# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PopulateDietFromJsonJob, type: :job do
  describe '#perform' do
    it 'builds diet_sets/meals/products and marks a generated diet ready' do
      diet = create(:diet, source: 'generated', status: 'generating', parsed_json: [
                      {
                        'day' => 1,
                        'meals' => [
                          {
                            'type' => 'breakfast',
                            'name' => 'Owsianka',
                            'instructions' => 'Zagotuj.',
                            'nutrition' => { 'kcal' => 300, 'protein' => 10, 'fat' => 5, 'carbs' => 40 },
                            'ingredients' => [{ 'product' => 'Płatki owsiane', 'quantity' => '60 g' }]
                          }
                        ]
                      }
                    ])

      described_class.new.perform(diet.id)

      diet.reload
      expect(diet.status).to eq('ready')
      expect(diet.diet_sets.count).to eq(1)
      expect(diet.meals.count).to eq(1)
      expect(diet.products.count).to eq(1)
    end

    it 'records the failure and re-raises on malformed parsed_json' do
      diet = create(:diet, source: 'generated', status: 'generating', parsed_json: [{ 'day' => 1 }])

      expect { described_class.new.perform(diet.id) }.to raise_error(NoMethodError)

      diet.reload
      expect(diet.status).to eq('failed')
      expect(diet.generation_error).to be_present
    end

    it 'does not touch status for a non-generated diet' do
      diet = create(:diet, source: 'pdf', parsed_json: [])

      described_class.new.perform(diet.id)

      expect(diet.reload.status).to eq('ready')
    end
  end
end
