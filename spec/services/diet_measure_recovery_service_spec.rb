# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietMeasureRecoveryService do
  describe '#call' do
    it 'restores ingredient measures from parsed_json and applies substitution factor' do
      user = create(:user)
      diet = create(:diet, user: user)
      diet.update!(
        parsed_json: [
          {
            'day' => 1,
            'meals' => [
              {
                'name' => 'Jogurt z płatkami',
                'type' => 'breakfast',
                'ingredients' => [
                  { 'product' => 'Banan', 'quantity' => '100g' },
                  { 'product' => 'Płatki owsiane', 'quantity' => '20g' }
                ]
              }
            ]
          }
        ]
      )

      diet_set = create(:diet_set, diet: diet, name: 'Dzień 1')
      meal = create(:meal, diet_set: diet_set, name: 'Jogurt z płatkami', meal_type: 'breakfast')
      banana = create(:product, meal: meal, diet_set: diet_set, name: 'Gruszka', base_product_name: 'Banan')
      oats = create(:product, meal: meal, diet_set: diet_set, name: 'Płatki owsiane')
      create(:product_substitution, user: user, source_product: 'Banan (100g)', replacement_product: 'Gruszka 180g')

      restored = described_class.new(diet: diet).call

      expect(restored).to eq(2)
      expect(banana.reload.ingredient_measures.first.amount).to be_within(0.01).of(180.0)
      expect(banana.ingredient_measures.first.unit).to eq('g')
      expect(oats.reload.ingredient_measures.first.amount).to be_within(0.01).of(20.0)
      expect(oats.ingredient_measures.first.unit).to eq('g')
    end
  end
end
