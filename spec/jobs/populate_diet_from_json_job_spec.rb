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

    describe 'category from the LLM ingredient' do
      let!(:dairy) { create(:category, name: 'Nabiał') }
      let!(:grains) { create(:category, name: 'Produkty zbożowe') }

      def diet_with_ingredient_category(category)
        create(:diet, source: 'pdf', parsed_json: [
                 {
                   'day' => 1,
                   'meals' => [
                     {
                       'type' => 'breakfast', 'name' => 'Owsianka', 'instructions' => '',
                       'nutrition' => { 'kcal' => 300, 'protein' => 10, 'fat' => 5, 'carbs' => 40 },
                       'ingredients' => [{ 'product' => 'Płatki owsiane', 'quantity' => '60 g', 'category' => category }]
                     }
                   ]
                 }
               ])
      end

      it 'assigns the LLM category as unconfirmed, ahead of local guessing' do
        diet = diet_with_ingredient_category('Nabiał')

        described_class.new.perform(diet.id)

        product_category = diet.reload.products.first.product_category
        expect(product_category).to have_attributes(category: dairy, state: false)
      end

      it 'falls back to the local classifier when the LLM category is unknown' do
        diet = diet_with_ingredient_category('Nieistniejąca')

        described_class.new.perform(diet.id)

        expect(diet.reload.products.first.category).to eq(grains)
      end
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
