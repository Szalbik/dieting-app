# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy

  # Optional: helper to aggregate products (group, sum, etc.)
  def grouped_items
    shopping_cart_items.includes(product: :category).group_by { |item| item.product.category }.map do |category, items|
      {
        category: category,
        products: items.group_by(&:product_id).map do |product_id, grouped_items|
          {
            product: grouped_items.first.product,
            quantity: grouped_items.sum(&:quantity),
          }
        end,
      }
    end
  end
end
