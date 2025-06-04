# frozen_string_literal: true

class DietDestroyer
  def self.call(diet)
    new(diet).call
  end

  def initialize(diet)
    @diet = diet
  end

  def call
    ActiveRecord::Base.transaction do
      puts "Usuwam dietę: \#{@diet.id} - \#{@diet.name}"

      meal_plan_ids = MealPlan
        .joins(:meal)
        .where(meals: { diet_set_id: @diet.diet_sets.ids })
        .pluck(:id)

      ShoppingCartItem.with_deleted
        .where(meal_plan_id: meal_plan_ids)
        .find_each(&:really_destroy!)

      MealPlan.where(id: meal_plan_ids).destroy_all

      @diet.diet_sets.each do |diet_set|
        diet_set.meals.each do |meal|
          meal.products.destroy_all
        end

        diet_set.meals.destroy_all
      end

      @diet.diet_sets.destroy_all
      @diet.destroy!

      puts "✔ Dieta \#{@diet.id} usunięta"
    end
  rescue => e
    puts "Błąd przy usuwaniu diety \#{@diet.id}: \#{e.message}"
    raise
  end
end
