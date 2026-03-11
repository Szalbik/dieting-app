# frozen_string_literal: true

class OriginalMealIngredientResolver
  def initialize(meal:)
    @meal = meal
  end

  def ingredient_for(product:)
    meal_hash = resolved_meal_hash
    return if meal_hash.blank?

    index = @meal.products.order(:id).pluck(:id).index(product.id)
    return if index.blank?

    Array(meal_hash['ingredients'])[index]
  end

  def original_name_for(product:)
    ingredient_for(product: product).to_h['product'].to_s.strip.presence
  end

  private

  def resolved_meal_hash
    return @resolved_meal_hash if defined?(@resolved_meal_hash)

    day_hash = parsed_day_hash
    return @resolved_meal_hash = nil if day_hash.blank?

    meals = Array(day_hash['meals'])
    normalized_name = ProductSubstitution.normalize_name(@meal.name)

    @resolved_meal_hash = meals.find do |meal_hash|
      ProductSubstitution.normalize_name(meal_hash['name']) == normalized_name
    end

    @resolved_meal_hash ||= begin
      meal_index = @meal.diet_set.meals.order(:id).pluck(:id).index(@meal.id)
      meals[meal_index] if meal_index
    end
  end

  def parsed_day_hash
    diet = @meal.diet_set&.diet
    return if diet.blank? || !diet.parsed_json.is_a?(Array)

    day_number = @meal.diet_set.name.to_s[/\d+/]&.to_i
    return if day_number.blank?

    diet.parsed_json.find { |row| row['day'].to_i == day_number }
  end
end
