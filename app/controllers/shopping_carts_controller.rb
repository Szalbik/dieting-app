# frozen_string_literal: true

class ShoppingCartsController < ApplicationController
  def update_from_meal_plans
    # Example: Gather products from meal plans scheduled on/after a date
    meal_plans = Current.user.meal_plans.where('meal_date >= ?', Date.current)
    products = meal_plans.flat_map(&:products)

    cart = Current.user.shopping_cart
    cart.shopping_cart_items.destroy_all  # Clear previous items, or update as needed

    # Aggregate products (e.g., sum quantities if a product appears in multiple meal plans)
    aggregated = products.group_by { |p| p.id }
    aggregated.each do |product_id, group|
      # Here you could determine quantity (or other measurements) based on your logic
      cart.shopping_cart_items.create!(
        product_id: product_id,
        quantity: group.size  # or any other logic to calculate quantity
      )
    end

    redirect_to shopping_cart_path, notice: 'Shopping cart updated.'
  end

  def show
    @shopping_cart = Current.user.shopping_cart
  end
end
