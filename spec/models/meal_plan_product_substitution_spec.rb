# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MealPlanProductSubstitution, type: :model do
  let(:user) { create(:user) }
  let(:diet) { create(:diet, user: user) }
  let(:diet_set) { create(:diet_set, diet: diet) }
  let(:meal) { create(:meal, diet_set: diet_set) }
  let(:meal_plan) { create(:meal_plan, meal: meal, diet_set_plan: create(:diet_set_plan, diet: diet, diet_set: diet_set)) }
  let(:product) { create(:product, meal: meal, diet_set: diet_set, name: 'Tunczyk') }

  describe '#capture_source_from!' do
    it 'captures the base product and computes multiplier from typed quantity' do
      product.ingredient_measures.create!(amount: 100.0, unit: 'g')

      substitution = described_class.new(
        user: user,
        meal_plan: meal_plan,
        product: product,
        replacement_product: 'Losos',
        replacement_amount: 140,
        replacement_unit: 'g'
      )

      substitution.capture_source_from!(product: product, base_name: 'Tunczyk')
      substitution.save!

      expect(substitution.source_product).to eq('Tunczyk')
      expect(substitution.replacement_product).to eq('Losos')
      expect(substitution.replacement_unit).to eq('g')
      expect(substitution.amount_multiplier).to be_within(0.001).of(1.4)
    end
  end

  describe '.local_factor_for' do
    it 'calculates ratios between local replacements and the base product' do
      create(
        :meal_plan_product_substitution,
        user: user,
        meal_plan: meal_plan,
        product: product,
        source_product: 'Tunczyk',
        source_amount: 100.0,
        source_unit: 'g',
        replacement_product: 'Losos',
        replacement_amount: 140.0,
        replacement_unit: 'g'
      )
      create(
        :meal_plan_product_substitution,
        user: user,
        meal_plan: meal_plan,
        product: product,
        source_product: 'Tunczyk',
        source_amount: 100.0,
        source_unit: 'g',
        replacement_product: 'Makrela',
        replacement_amount: 120.0,
        replacement_unit: 'g'
      )

      expect(
        described_class.local_factor_for(
          user: user,
          meal_plan: meal_plan,
          product: product,
          base_name: 'Tunczyk',
          from_name: 'Tunczyk',
          to_name: 'Losos'
        )
      ).to be_within(0.001).of(1.4)

      expect(
        described_class.local_factor_for(
          user: user,
          meal_plan: meal_plan,
          product: product,
          base_name: 'Tunczyk',
          from_name: 'Losos',
          to_name: 'Makrela'
        )
      ).to be_within(0.001).of(1.2 / 1.4)
    end
  end
end
