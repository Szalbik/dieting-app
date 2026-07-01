# frozen_string_literal: true

# A user-authored, reusable meal — the building block for composing a
# manual diet day from your own recipes (see Recipe#to_meal!).
class Recipe < ApplicationRecord
  belongs_to :user

  attribute :ingredients, :json, default: []

  validates :name, presence: true
  validates :meal_type, inclusion: { in: Meal::SLOTS.keys }, allow_blank: true

  # Parses one "Produkt - 200 g" line into {name:, amount:, unit:}, mirroring
  # the quantity regex PopulateDietFromJsonJob already uses for parsed diets.
  def self.parse_ingredient_line(line)
    name, quantity = line.to_s.split(/\s+-\s+/, 2)
    amount, unit = quantity.to_s.match(/([\d.,]+)\s*(.*)/)&.captures || [nil, quantity]
    { 'name' => name.to_s.strip, 'amount' => amount&.tr(',', '.')&.to_f, 'unit' => unit&.strip }
  end

  # Inverse of parse_ingredient_line — pre-fills the edit-form textarea.
  def ingredients_text
    Array(ingredients).map { |ing| "#{ing['name']} - #{ing['amount']} #{ing['unit']}".strip }.join("\n")
  end

  # Materializes this recipe as a Meal (+ Products + IngredientMeasures)
  # inside the given diet_set.
  def to_meal!(diet_set)
    new_meal = diet_set.meals.create!(
      meal_type: meal_type,
      name: name,
      instructions: instructions,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carbs: carbs
    )

    Array(ingredients).each do |ing|
      product = new_meal.products.create!(name: ing['name'])
      product.ingredient_measures.create!(amount: ing['amount'], unit: ing['unit'])
    end

    new_meal
  end
end
