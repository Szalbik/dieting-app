# frozen_string_literal: true

class ShoppingCartItem < ApplicationRecord
  acts_as_paranoid

  belongs_to :shopping_cart
  belongs_to :product
  belongs_to :meal_plan

  delegate :selected_for_cart, to: :meal_plan

  scope :with_current_or_future_diet_set_plan, -> {
    where(<<~SQL, Date.current)
      EXISTS (
        SELECT 1 FROM diet_set_plans mp
        JOIN diet_sets ds ON mp.diet_set_id = ds.id
        JOIN meals m ON m.diet_set_id = ds.id
        JOIN products p ON p.meal_id = m.id
        WHERE p.id = shopping_cart_items.product_id
          AND mp.date >= ?
      )
    SQL
  }
end
