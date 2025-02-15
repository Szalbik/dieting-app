# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy

  # Optional: helper to aggregate products (group, sum, etc.)
  def grouped_items
    shopping_cart_items.includes(product: :category)
      .group_by { |item| item.product.category }
      .map do |category, items|
        products = items.group_by { |item| item.product.name }.map do |name, grouped_items|
          total = grouped_items.sum { |item| item.product.meal.selected_for_cart ? item.quantity : 0 }
          { product: grouped_items.first.product, quantity: total } if total > 0
        end.compact

        { category: category, products: products } if products.any?
      end.compact
  end
end
