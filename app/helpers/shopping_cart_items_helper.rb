# frozen_string_literal: true

module ShoppingCartItemsHelper
  def category_empty?(category)
    Current.user.shopping_cart.shopping_cart_items.joins(product: :category).where(categories: { name: category&.name || 'Inne' }).empty?
  end
end
