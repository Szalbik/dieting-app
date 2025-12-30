# frozen_string_literal: true

class PopulateDietFromJsonJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)
    parsed = diet.parsed_json
    return unless parsed.is_a?(Array)

    ActiveRecord::Base.transaction do
      # Clear existing sets and associated meals/products
      diet.diet_sets.destroy_all

      parsed.each do |day_hash|
        day_number = day_hash['day']
        # Create a new set for each day (no position attribute)
        set = diet.diet_sets.create!(name: "Dzień #{day_number}")

        day_hash['meals'].each do |meal_hash|
          meal = set.meals.create!(
            meal_type: meal_hash['type'],
            name: meal_hash['name'],
            instructions: meal_hash['instructions'],
            kcal: meal_hash.dig('nutrition', 'kcal'),
            protein: meal_hash.dig('nutrition', 'protein'),
            fat: meal_hash.dig('nutrition', 'fat'),
            carbs: meal_hash.dig('nutrition', 'carbs')
          )

          Array(meal_hash['ingredients']).each do |ing|
            product = meal.products.create!(name: ing['product'])
            quantity = ing['quantity'].to_s
            # Parse amount and unit if possible
            amount, unit = quantity.match(/([\d.,]+)\s*(.*)/)&.captures || [nil, quantity]
            product.ingredient_measures.create!(amount: amount&.tr(',', '.')&.to_f, unit: unit)
          end
        end
      end
    end
    
    # Classify products after they're created
    ClassifyProductsJob.perform_later(diet.id)
  end
end
