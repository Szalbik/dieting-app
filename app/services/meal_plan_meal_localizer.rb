# frozen_string_literal: true

class MealPlanMealLocalizer
  def initialize(meal_plan:)
    @meal_plan = meal_plan
  end

  def localize_product(product:)
    return product unless localize?

    duplicate_meal_and_products.fetch(product.id)
  end

  private

  attr_reader :meal_plan

  def localize?
    meal_plan.meal.meal_plans.where.not(id: meal_plan.id).exists?
  end

  def duplicate_meal_and_products
    return @duplicate_meal_and_products if defined?(@duplicate_meal_and_products)

    product_map = {}

    Meal.transaction do
      duplicated_meal = meal_plan.diet_set_plan.diet_set.meals.create!(
        name: meal_plan.meal.name,
        instructions: meal_plan.meal.instructions,
        meal_type: meal_plan.meal.meal_type,
        kcal: meal_plan.meal.kcal,
        protein: meal_plan.meal.protein,
        fat: meal_plan.meal.fat,
        carbs: meal_plan.meal.carbs
      )

      meal_plan.meal.products.includes(:ingredient_measures, :product_category).order(:id).each do |source_product|
        duplicated_product = duplicated_meal.products.create!(
          name: source_product.name,
          unit: source_product.unit,
          diet_set: meal_plan.diet_set_plan.diet_set,
          associated_product_id: source_product.associated_product_id,
          base_product_name: source_product.base_product_name,
          canonical_product: source_product.canonical_product,
          base_canonical_product: source_product.base_canonical_product
        )

        source_product.ingredient_measures.each do |measure|
          duplicated_product.ingredient_measures.create!(
            amount: measure.amount,
            unit: measure.unit
          )
        end

        if source_product.product_category.present?
          if duplicated_product.product_category.present?
            duplicated_product.product_category.update!(
              category: source_product.product_category.category,
              state: source_product.product_category.state
            )
          else
            duplicated_product.create_product_category!(
              category: source_product.product_category.category,
              state: source_product.product_category.state
            )
          end
        end

        product_map[source_product.id] = duplicated_product
      end

      meal_plan.update!(meal: duplicated_meal)

      meal_plan.meal_plan_product_substitutions.find_each do |substitution|
        duplicated_product = product_map[substitution.product_id]
        next if duplicated_product.blank?

        substitution.update!(product: duplicated_product)
      end
    end

    @duplicate_meal_and_products = product_map
  end
end
