# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OriginalProductNameRestoreService do
  describe '#call' do
    it 'restores the original ingredient name when current name only reflects canonical base' do
      user = create(:user)
      diet = create(:diet, user: user)
      diet.update!(
        parsed_json: [
          {
            'day' => 1,
            'meals' => [
              {
                'name' => 'Jogurt z dodatkami',
                'ingredients' => [
                  { 'product' => 'Jogurt naturalny', 'quantity' => '150g' }
                ]
              }
            ]
          }
        ]
      )

      diet_set = create(:diet_set, diet: diet, name: 'Dzień 1')
      meal = create(:meal, diet_set: diet_set, name: 'Jogurt z dodatkami')
      product = create(
        :product,
        meal: meal,
        diet_set: diet_set,
        name: 'Jogurt naturalny 2% tłuszczu',
        base_product_name: 'Jogurt naturalny 2% tłuszczu'
      )

      updated = described_class.new(diet: diet).call

      expect(updated).to eq(1)
      expect(product.reload.name).to eq('Jogurt naturalny')
      expect(product.base_product_name).to eq('Jogurt naturalny 2% tłuszczu')
    end
  end
end
