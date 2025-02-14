# frozen_string_literal: true

class ShoppingCartItemsController < ApplicationController
  def destroy
    @product = Current.user.products.find(params[:id])
    @items = Current.user.shopping_cart.shopping_cart_items
      .joins(:product)
      .where(products: { name: @product.name })
    @items.destroy_all

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shopping_cart_path }
    end
  end
end
