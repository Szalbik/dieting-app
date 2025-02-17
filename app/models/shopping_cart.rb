# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy

  # Optional: helper to aggregate products (group, sum, etc.)
  def grouped_items
    shopping_cart_items.with_current_or_future_meal_plan.includes(product: :category)
      .group_by { |item| item.product.category }
      .map do |category, items|
      products = items.group_by { |item| item.product.id }.map do |id, grouped_items|
        # Since the product is the same (same ID), the ingredient measures should be the same.
        total = grouped_items.sum { |item| item.product.meal.selected_for_cart ? item.quantity : 0 }
        { product: grouped_items.first.product, quantity: total } if total > 0
      end.compact
      { category: category, products: products } if products.any?
    end.compact
  end
end
