# frozen_string_literal: true

class Chat::DietMealConsolidator
  ACCESSORY_BEVERAGE_KEYWORDS = %w[
    drenanat
    levanat
    infunat
    instant
    te rojo
    herbata
    tea
  ].freeze

  NUTRITION_FIELDS = %w[kcal protein fat carbs].freeze

  def initialize(days, expected_meals_per_day: nil)
    @days = Array(days)
    @expected_meals_per_day = expected_meals_per_day
  end

  def call
    @days.map do |day|
      day.deep_dup.merge('meals' => consolidate_meals(day['meals']))
    end
  end

  private

  def consolidate_meals(meals)
    merged_accessories = merge_accessory_beverages(Array(meals))
    merge_to_expected_count(merge_trailing_dinner_components(merged_accessories))
  end

  def merge_accessory_beverages(meals)
    meals.each_with_object([]) do |meal, merged|
      normalized_meal = meal.deep_dup

      if merged.any? && accessory_beverage?(normalized_meal)
        merged[-1] = merge_meals(merged.last, normalized_meal)
      else
        merged << normalized_meal
      end
    end
  end

  def merge_trailing_dinner_components(meals)
    dinner_index = meals.index { |meal| meal['type'] == 'dinner' }
    return meals if dinner_index.nil? || dinner_index == meals.length - 1

    consolidated_dinner = meals[dinner_index]
    meals[(dinner_index + 1)..].each do |meal|
      consolidated_dinner = merge_meals(consolidated_dinner, meal)
    end

    meals[0...dinner_index] + [consolidated_dinner]
  end

  def merge_to_expected_count(meals)
    return meals if @expected_meals_per_day.blank? || meals.size <= @expected_meals_per_day

    consolidated_meals = meals.map(&:deep_dup)

    while consolidated_meals.size > @expected_meals_per_day
      merge_index = candidate_index_for_expected_count(consolidated_meals)
      target_index = merge_index.zero? ? 1 : merge_index - 1
      consolidated_meals[target_index] = merge_meals(consolidated_meals[target_index], consolidated_meals[merge_index])
      consolidated_meals.delete_at(merge_index)
    end

    consolidated_meals
  end

  def candidate_index_for_expected_count(meals)
    candidate = meals.each_with_index
      .reject { |_meal, index| index.zero? }
      .min_by do |meal, index|
        [
          canonical_meal_type_rank(meal['type']),
          meal.dig('nutrition', 'kcal').to_f,
          index
        ]
      end

    candidate ? candidate.last : meals.length - 1
  end

  def canonical_meal_type_rank(meal_type)
    case meal_type
    when 'snack'
      0
    when 'breakfast', 'lunch', 'dinner'
      1
    else
      2
    end
  end

  def accessory_beverage?(meal)
    ingredients = Array(meal['ingredients'])
    return false unless ingredients.one?

    kcal = meal.dig('nutrition', 'kcal')
    return false if kcal.nil? || kcal.to_f > 10

    searchable_text = [
      meal['name'],
      ingredients.first['product'],
      ingredients.first['quantity']
    ].join(' ').downcase

    ACCESSORY_BEVERAGE_KEYWORDS.any? { |keyword| searchable_text.include?(keyword) }
  end

  def merge_meals(base_meal, extra_meal)
    merged = base_meal.deep_dup
    merged['name'] = merge_text_fields(base_meal['name'], extra_meal['name'], separator: ', ')
    merged['instructions'] = merge_text_fields(base_meal['instructions'], extra_meal['instructions'], separator: "\n")
    merged['ingredients'] = Array(base_meal['ingredients']) + Array(extra_meal['ingredients'])
    merged['nutrition'] = merge_nutrition(base_meal['nutrition'], extra_meal['nutrition'])
    merged
  end

  def merge_text_fields(first_value, second_value, separator:)
    [first_value, second_value]
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .join(separator)
  end

  def merge_nutrition(first_nutrition, second_nutrition)
    NUTRITION_FIELDS.each_with_object({}) do |field, merged|
      first_value = first_nutrition&.[](field)
      second_value = second_nutrition&.[](field)
      merged[field] = [first_value, second_value].compact.sum
    end
  end
end
