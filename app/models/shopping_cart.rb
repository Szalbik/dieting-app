# frozen_string_literal: true

class ShoppingCart < ApplicationRecord
  belongs_to :user
  has_many :shopping_cart_items, dependent: :destroy

  # Optional: helper to aggregate products (group, sum, etc.)
  def grouped_items
    # You can perform grouping/aggregation here if needed.
    # For simplicity, let’s assume you want to group by product category:
    shopping_cart_items.includes(product: :category).group_by { |item| item.product.category }
  end
end
