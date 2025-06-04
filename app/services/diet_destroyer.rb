# frozen_string_literal: true

class DietDestroyer
  def initialize(diet)
    @diet = diet
  end

  def call
    ActiveRecord::Base.transaction do
      destroy_meals_and_related_data
      @diet.destroy!
    end
  end

  private

  def destroy_meals_and_related_data
    @diet.meals.find_each do |meal|
      meal_plan_ids = MealPlan.where(meal_id: meal.id).pluck(:id)

      # Zniszcz ShoppingCartItems (z paranoia, jeśli używasz)
      ShoppingCartItem.with_deleted.where(meal_plan_id: meal_plan_ids).find_each(&:really_destroy!)

      # Zniszcz MealPlany i produkty powiązane z tym mealem
      MealPlan.where(id: meal_plan_ids).destroy_all
      meal.products.destroy_all

      meal.destroy!
    end
  end
end
