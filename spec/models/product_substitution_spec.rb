# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductSubstitution, type: :model do
  describe '.suggestions_for_names' do
    let(:user) { create(:user) }

    before do
      create(:product_substitution, user: user, source_product: 'tunczyk', replacement_product: 'losos')
      create(:product_substitution, user: user, source_product: 'jogurt naturalny', replacement_product: 'skyr')
    end

    it 'returns replacement suggestions for similar names' do
      result = described_class.suggestions_for_names(
        user: user,
        product_names: ['Tunczyk w sosie wlasnym', 'Jogurt naturalny 2%']
      )

      expect(result['Tunczyk w sosie wlasnym']).to include('losos')
      expect(result['Jogurt naturalny 2%']).to include('skyr')
    end

    it 'returns empty array when no substitution is found' do
      result = described_class.suggestions_for_names(
        user: user,
        product_names: ['kasza gryczana']
      )

      expect(result['kasza gryczana']).to eq([])
    end
  end

  describe '.connected_names_for' do
    let(:user) { create(:user) }

    before do
      create(:product_substitution, user: user, source_product: 'Bułka grahamka', replacement_product: 'Chleb żytni')
      create(:product_substitution, user: user, source_product: 'Bułka grahamka',
                                    replacement_product: 'Bułka orkiszowa')
      create(:product_substitution, user: user, source_product: 'Bułka orkiszowa', replacement_product: 'Chleb razowy')
    end

    it 'returns connected replacement names for product cluster' do
      names = described_class.connected_names_for(user: user, product_name: 'Bułka grahamka')

      expect(names).to include('Bułka grahamka', 'Chleb żytni', 'Bułka orkiszowa', 'Chleb razowy')
    end
  end

  describe 'quantity parsing and conversion' do
    let(:user) { create(:user) }

    it 'strips quantity from names and calculates amount multiplier' do
      substitution = create(
        :product_substitution,
        user: user,
        source_product: 'Banan (100g)',
        replacement_product: '180g gruszki'
      )

      expect(substitution.source_product).to eq('Banan')
      expect(substitution.replacement_product).to eq('gruszki')
      expect(substitution.amount_multiplier).to be_within(0.001).of(1.8)
    end

    it 'computes conversion factor between connected names' do
      create(:product_substitution, user: user, source_product: 'Banan (100g)', replacement_product: '180g gruszki')
      create(:product_substitution, user: user, source_product: 'Banan (100g)', replacement_product: '120g jabłko')

      factor = described_class.conversion_factor_between(
        user: user,
        from_name: 'gruszki',
        to_name: 'jabłko'
      )

      expect(factor).to be_within(0.001).of(120.0 / 180.0)
    end
  end

  describe 'local cycle behavior' do
    let(:user) { create(:user) }

    before do
      create(:product_substitution, user: user, source_product: 'Banan (100g)', replacement_product: 'Gruszka 180g')
      create(:product_substitution, user: user, source_product: 'Banan (100g)', replacement_product: 'Jablko 120g')
      create(:product_substitution, user: user, source_product: 'Gruszka 180g', replacement_product: 'Kiwi 150g')
    end

    it 'builds cycle only from direct replacements of base product' do
      cycle = described_class.local_cycle_for(user: user, base_name: 'Banan')

      expect(cycle).to eq(%w[Banan Gruszka Jablko])
      expect(cycle).not_to include('Kiwi')
    end

    it 'calculates local factor for replacement-to-replacement via base ratios' do
      factor = described_class.local_factor_for(
        user: user,
        base_name: 'Banan',
        from_name: 'Gruszka',
        to_name: 'Jablko'
      )

      expect(factor).to be_within(0.001).of(120.0 / 180.0)
    end

    it 'deduplicates inflected variants in local cycle to canonical catalog names' do
      isolated_user = create(:user)
      diet = create(:diet, user: isolated_user)
      diet_set = create(:diet_set, diet: diet)
      meal = create(:meal, diet_set: diet_set)
      create(:product, name: 'Jabłko', meal: meal, diet_set: diet_set)
      create(:product_substitution, user: isolated_user, source_product: 'Banan', replacement_product: 'jabłka')

      cycle = described_class.local_cycle_for(user: isolated_user, base_name: 'Banan')
      apple_like = cycle.select { |name| described_class.normalize_name(name).include?('jablk') }

      expect(apple_like.size).to eq(1)
      expect(apple_like.first).to eq('Jabłko')
    end

    it 'stores canonical source and replacement products' do
      isolated_user = create(:user)
      substitution = create(
        :product_substitution,
        user: isolated_user,
        source_product: 'Banan (100g)',
        replacement_product: 'gruszki 180g'
      )

      expect(substitution.source_canonical_product).to be_present
      expect(substitution.replacement_canonical_product).to be_present
      expect(substitution.source_canonical_product.name).to eq('Banan')
      expect(substitution.replacement_canonical_product.name).to eq('gruszki')
    end
  end
end
