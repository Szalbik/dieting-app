# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Meal, type: :model do
  describe '#copy_into' do
    it 'deep-copies the meal, its products and ingredient measures into another diet_set' do
      source_meal = create(:meal, name: 'Kurczak z ryżem', meal_type: 'lunch', kcal: 600)
      product = create(:product, meal: source_meal, name: 'Ryż')
      product.ingredient_measures.create!(amount: 100.0, unit: 'g')
      target_diet_set = create(:diet_set)

      copy = source_meal.copy_into(target_diet_set)

      expect(copy).not_to eq(source_meal)
      expect(copy.diet_set).to eq(target_diet_set)
      expect(copy.name).to eq('Kurczak z ryżem')
      expect(copy.kcal).to eq(600)
      expect(copy.products.count).to eq(1)
      expect(copy.products.first.name).to eq('Ryż')
      expect(copy.products.first.ingredient_measures.first.amount).to eq(100.0)

      # snapshot: deleting the source doesn't touch the copy
      source_meal.destroy
      expect(copy.reload).to be_persisted
    end
  end

  describe '#save_as_recipe!' do
    it 'builds a Recipe from the meal and its products' do
      user = create(:user)
      meal = create(:meal, name: 'Sałatka', meal_type: 'dinner', kcal: 400)
      product = create(:product, meal: meal, name: 'Sałata')
      product.ingredient_measures.create!(amount: 50.0, unit: 'g')

      recipe = meal.save_as_recipe!(user)

      expect(recipe.user).to eq(user)
      expect(recipe.name).to eq('Sałatka')
      expect(recipe.kcal).to eq(400)
      expect(recipe.ingredients).to eq([{ 'name' => 'Sałata', 'amount' => 50.0, 'unit' => 'g' }])
    end
  end
end
