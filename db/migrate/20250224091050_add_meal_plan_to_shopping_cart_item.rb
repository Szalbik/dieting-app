class AddMealPlanToShoppingCartItem < ActiveRecord::Migration[8.0]
  def change
    add_reference :shopping_cart_items, :meal_plan, null: false, foreign_key: true
  end
end
