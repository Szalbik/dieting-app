# frozen_string_literal: true

class Meal < ApplicationRecord
  SLOTS = {
    'breakfast' => 'Śniadanie',
    'second_breakfast' => 'II śniadanie',
    'lunch' => 'Obiad',
    'afternoon_snack' => 'Podwieczorek',
    'dinner' => 'Kolacja',
    'snack' => 'Przekąska',
  }.freeze

  belongs_to :diet_set
  has_many :products, dependent: :nullify
  has_many :meal_plans, dependent: :destroy

  # Deep-copies this meal (and its products/ingredient measures) into another
  # diet_set. Used to compose a day from a meal that lives in another diet —
  # a snapshot, so later edits/deletion of the source meal don't affect it.
  def copy_into(diet_set)
    new_meal = diet_set.meals.create!(
      meal_type: meal_type,
      name: name,
      instructions: instructions,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carbs: carbs
    )

    products.each do |product|
      new_product = new_meal.products.create!(name: product.name)
      product.ingredient_measures.each do |measure|
        new_product.ingredient_measures.create!(amount: measure.amount, unit: measure.unit)
      end
    end

    new_meal
  end

  def save_as_recipe!(user)
    user.recipes.create!(
      name: name,
      meal_type: meal_type,
      instructions: instructions,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carbs: carbs,
      ingredients: products.map do |product|
        measure = product.ingredient_measures.first
        { 'name' => product.name, 'amount' => measure&.amount, 'unit' => measure&.unit }
      end
    )
  end
end
