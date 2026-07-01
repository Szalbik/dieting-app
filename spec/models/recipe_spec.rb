# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Recipe, type: :model do
  describe '.parse_ingredient_line' do
    it 'splits "name - amount unit" into parts' do
      expect(Recipe.parse_ingredient_line('Kurczak - 200 g')).to eq(
        'name' => 'Kurczak', 'amount' => 200.0, 'unit' => 'g'
      )
    end

    it 'handles comma decimals' do
      expect(Recipe.parse_ingredient_line('Oliwa - 1,5 łyżki')).to eq(
        'name' => 'Oliwa', 'amount' => 1.5, 'unit' => 'łyżki'
      )
    end
  end

  describe 'meal_type validation' do
    it 'allows a blank meal_type (submitted as an empty string from the "any slot" select option)' do
      recipe = build(:recipe, user: create(:user), meal_type: '')
      expect(recipe).to be_valid
    end

    it 'rejects a meal_type outside Meal::SLOTS' do
      recipe = build(:recipe, user: create(:user), meal_type: 'brunch')
      expect(recipe).not_to be_valid
    end
  end

  describe '#ingredients_text' do
    it 'renders ingredients back as lines' do
      recipe = build(:recipe, ingredients: [{ 'name' => 'Ryż', 'amount' => 100.0, 'unit' => 'g' }])
      expect(recipe.ingredients_text).to eq('Ryż - 100.0 g')
    end
  end

  describe '#to_meal!' do
    it 'creates a meal with products and ingredient measures inside the given diet_set' do
      recipe = create(:recipe, name: 'Owsianka', meal_type: 'breakfast', kcal: 350,
                               ingredients: [{ 'name' => 'Płatki owsiane', 'amount' => 50.0, 'unit' => 'g' }])
      diet_set = create(:diet_set)

      meal = recipe.to_meal!(diet_set)

      expect(meal.diet_set).to eq(diet_set)
      expect(meal.name).to eq('Owsianka')
      expect(meal.meal_type).to eq('breakfast')
      expect(meal.kcal).to eq(350)
      expect(meal.products.count).to eq(1)
      expect(meal.products.first.name).to eq('Płatki owsiane')
      expect(meal.products.first.ingredient_measures.first.amount).to eq(50.0)
    end
  end
end
