# frozen_string_literal: true

class ShoppingCartSyncService
  def initialize(shopping_cart:, users:)
    @shopping_cart = shopping_cart
    @users = Array(users).compact.uniq
  end

  def call
    mark_completed_diet_set_plans!

    # Preserve checked-off items across the wipe-and-recreate below, so a
    # resync (e.g. adding a future day) doesn't un-check already-bought items.
    bought_keys = shopping_cart.shopping_cart_items
      .where(bought: true)
      .pluck(:product_id, :meal_plan_id, :date).to_set

    grouped_items = Hash.new(0)
    meal_plans = future_selected_meal_plans

    meal_plans.each do |meal_plan|
      meal_plan.meal.products.each do |product|
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
          quantity: quantity,
          bought: bought_keys.include?([product_id, meal_plan_id, date])
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
      .where(diet_set_plans: { shopping_done: false, id: latest_diet_set_plan_ids(user_ids) })
      .includes(:diet_set_plan, meal: :products)
  end

  # A single diet can have more than one DietSetPlan for the same date
  # (swap/recreate leave the old one behind). Only the newest plan per
  # (diet, date) should feed the cart, or a stale plan's meal_plans get
  # synced alongside the current one as duplicates. Grouping is per-diet
  # (not just per-date) so a shared cart with multiple users' diets landing
  # on the same date doesn't get one user's plan dropped as "stale".
  def latest_diet_set_plan_ids(user_ids)
    DietSetPlan
      .joins(:diet)
      .where(diets: { user_id: user_ids })
      .where('date >= ?', Date.current)
      .pluck(:id, :diet_id, :date, :created_at)
      .group_by { |(_id, diet_id, date, _created_at)| [diet_id, date] }
      .values
      .map { |rows| rows.max_by { |(_id, _diet_id, _date, created_at)| created_at }.first }
  end
end
