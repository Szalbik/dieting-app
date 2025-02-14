# frozen_string_literal: true

module ShoppingCartItemsHelper
  def category_empty?(category)
    Current.user.shopping_cart.shopping_cart_items.joins(product: :category).where(categories: { name: category&.name || 'Inne' }).empty?
  end

  def shopping_cart_item_id_for(category, product)
    "shopping-cart-item-#{category&.name.parameterize || 'inne'}-#{product.name.parameterize}"
  end
end
