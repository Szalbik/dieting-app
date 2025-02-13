# frozen_string_literal: true

class ShoppingCartItemsController < ApplicationController
  def destroy
    item = Current.user.shopping_cart.shopping_cart_items.find(params[:id])
    item.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("shopping_cart_item_#{item.id}")
      end
      format.html { redirect_to shopping_cart_path }
    end
  end
end
