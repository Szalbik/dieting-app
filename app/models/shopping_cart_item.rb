# frozen_string_literal: true

class ShoppingCartItem < ApplicationRecord
  acts_as_paranoid

  belongs_to :shopping_cart
  belongs_to :product

  scope :with_current_or_future_meal_plan, -> {
    where(<<~SQL, Date.current)
      EXISTS (
        SELECT 1 FROM meal_plans mp
        JOIN diet_sets ds ON mp.diet_set_id = ds.id
        JOIN meals m ON m.diet_set_id = ds.id
        JOIN products p ON p.meal_id = m.id
        WHERE p.id = shopping_cart_items.product_id
          AND mp.date >= ?
      )
    SQL
  }
end
