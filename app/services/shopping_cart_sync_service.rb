# frozen_string_literal: true

class ShoppingCartSyncService
  def initialize(shopping_cart:, users:)
    @shopping_cart = shopping_cart
    @users = Array(users).compact.uniq
  end

  def call
    mark_completed_diet_set_plans!

    grouped_items = Hash.new(0)
    meal_plans = future_selected_meal_plans

    meal_plans.each do |meal_plan|
      meal_plan.products.each do |product|
        grouped_items[[product.id, meal_plan.id, meal_plan.diet_set_plan.date]] += 1
      end
    end

    ActiveRecord::Base.transaction do
      shopping_cart.shopping_cart_items.with_deleted.delete_all

      grouped_items.each do |(product_id, meal_plan_id, date), quantity|
        shopping_cart.shopping_cart_items.create!(
          product_id: product_id,
          meal_plan_id: meal_plan_id,
          date: date,
          quantity: quantity
        )
      end
    end

    shopping_cart.broadcast_contents
  end

  private

  attr_reader :shopping_cart, :users

  def mark_completed_diet_set_plans!
    all_dates = shopping_cart.shopping_cart_items.with_deleted.distinct.pluck(:date)
    active_dates = shopping_cart.shopping_cart_items.distinct.pluck(:date)
    completed_dates = all_dates - active_dates

    return if completed_dates.empty?

    DietSetPlan
      .joins(:diet)
      .where(diets: { user_id: users.map(&:id) })
      .where(date: completed_dates)
      .update_all(shopping_done: true)
  end

  def future_selected_meal_plans
    user_ids = users.map(&:id)
    return MealPlan.none if user_ids.empty?

    MealPlan
      .joins(diet_set_plan: :diet)
      .where(diets: { user_id: user_ids })
      .where(selected_for_cart: true)
      .where('diet_set_plans.date >= ?', Date.current)
      .where(diet_set_plans: { shopping_done: false })
      .includes(:diet_set_plan, meal: :products)
  end
end
