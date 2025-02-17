# frozen_string_literal: true

class ShoppingCartItem < ApplicationRecord
  belongs_to :shopping_cart
  belongs_to :product

  scope :with_current_or_future_meal_plan, -> {
    joins(product: { meal: { diet_set: :meal_plans } })
      .where('meal_plans.date >= ?', Date.current)
  }
end
