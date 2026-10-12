# frozen_string_literal: true

module ShoppingCartItemsHelper
  def shopping_cart_item_id_for(category, product_name)
    "shopping-cart-item-#{category&.name&.parameterize || 'inne'}-#{product_name.to_s.parameterize}"
  end

  def shopping_cart_member_label(user)
    user.first_name.presence || user.email_address
  end
end
