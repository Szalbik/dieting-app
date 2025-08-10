# frozen_string_literal: true

class ShoppingCartItem < ApplicationRecord
  acts_as_paranoid

  belongs_to :shopping_cart
  belongs_to :product
  belongs_to :meal_plan

  delegate :selected_for_cart, to: :meal_plan

  def self.with_current_or_future_diet_set_plan_for_user(user)
    user_diet_ids = user.diets.pluck(:id)

    where(<<~SQL, Date.current, user_diet_ids, user_diet_ids)
      EXISTS (
        SELECT 1
        FROM diet_set_plans mp
        JOIN diet_sets ds ON mp.diet_set_id = ds.id
        JOIN meals m ON m.diet_set_id = ds.id
        JOIN products p ON p.meal_id = m.id
        WHERE p.id = shopping_cart_items.product_id
          AND mp.date >= ?
          AND mp.diet_id IN (?)
          AND mp.created_at = (
            SELECT MAX(mp2.created_at)
            FROM diet_set_plans mp2
            JOIN diet_sets ds2 ON mp2.diet_set_id = ds2.id
            WHERE mp2.date = mp.date
              AND mp2.diet_id IN (?)
          )
      )
    SQL
  end
end
