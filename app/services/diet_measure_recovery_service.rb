# frozen_string_literal: true

class DietMeasureRecoveryService
  BRACKET_MEASURE_REGEX = /\((?<amount>\d+(?:[.,]\d+)?)\s*(?<unit>[[:alpha:]\p{L}%\.]+)\)/u
  SIMPLE_MEASURE_REGEX = /(?<amount>\d+(?:[.,]\d+)?)\s*(?<unit>[[:alpha:]\p{L}%\.]+)/u

  def initialize(diet:)
    @diet = diet
  end

  def call
    return 0 if @diet.blank? || !@diet.parsed_json.is_a?(Array)

    restored = 0

    ActiveRecord::Base.transaction do
      @diet.parsed_json.each do |day_hash|
        diet_set = @diet.diet_sets.find_by(name: "Dzień #{day_hash['day']}")
        next unless diet_set

        Array(day_hash['meals']).each do |meal_hash|
          meal = find_meal(diet_set: diet_set, meal_hash: meal_hash)
          next unless meal

          restored += restore_meal_products(meal: meal, ingredients: Array(meal_hash['ingredients']))
        end
      end
    end

    restored
  end

  private

  def find_meal(diet_set:, meal_hash:)
    name = meal_hash['name'].to_s
    meal_type = meal_hash['type'].to_s

    diet_set.meals.find_by(name: name) ||
      diet_set.meals.find_by(meal_type: meal_type, name: name) ||
      diet_set.meals.order(:id).detect do |meal|
        ProductSubstitution.normalize_name(meal.name) == ProductSubstitution.normalize_name(name)
      end
  end

  def restore_meal_products(meal:, ingredients:)
    restored = 0
    products = meal.products.order(:id).to_a

    products.each_with_index do |product, index|
      ingredient = ingredients[index]
      next if ingredient.blank?

      amount, unit = extract_measure(ingredient['quantity'].to_s)
      next if amount.blank? || unit.blank?

      product.ingredient_measures.destroy_all

      adjusted_amount = adjusted_amount_for(product: product, base_amount: amount, ingredient_name: ingredient['product'])
      product.ingredient_measures.create!(amount: adjusted_amount.round(2), unit: unit)
      restored += 1
    end

    restored
  end

  def extract_measure(quantity_text)
    text = quantity_text.to_s.strip
    return [nil, nil] if text.blank?

    match = text.match(BRACKET_MEASURE_REGEX) || text.match(/\A#{SIMPLE_MEASURE_REGEX}\z/u)
    return [nil, nil] unless match

    amount = match[:amount].to_s.tr(',', '.').to_f
    unit = ProductSubstitution.normalize_unit(match[:unit])
    return [nil, nil] if amount <= 0 || unit.blank?

    [amount, unit]
  end

  def adjusted_amount_for(product:, base_amount:, ingredient_name:)
    base_name = product.base_product_name.presence || ingredient_name.to_s
    factor = ProductSubstitution.local_factor_for(
      user: @diet.user,
      base_name: base_name,
      from_name: base_name,
      to_name: product.name
    ).to_f
    factor = 1.0 if factor <= 0

    base_amount.to_f * factor
  end
end
