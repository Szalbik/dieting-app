# frozen_string_literal: true

class CustomCartItemsController < ApplicationController
  def create
    @shopping_cart = Current.user.shopping_cart
    @custom_item = @shopping_cart.custom_cart_items.build(custom_cart_item_params)

    if @custom_item.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to shopping_cart_path, notice: 'Produkt został dodany do listy.' }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :create_error, status: :unprocessable_entity }
        format.html { redirect_to shopping_cart_path, alert: @custom_item.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @custom_item = Current.user.shopping_cart.custom_cart_items.find(params[:id])
    @custom_item.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shopping_cart_path, notice: 'Produkt został usunięty z listy.' }
    end
  end

  def toggle_bought
    shopping_cart = Current.user.shopping_cart
    custom_item = shopping_cart.custom_cart_items.find(params[:id])
    custom_item.update(bought: !custom_item.bought) # after_commit broadcasts to the shared cart

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('shopping_cart',
          partial: 'shopping_carts/shopping_cart', locals: { shopping_cart: shopping_cart })
      end
      format.html { redirect_to shopping_cart_path }
    end
  end

  private

  def custom_cart_item_params
    params.require(:custom_cart_item).permit(:name, :quantity, :unit)
  end
end
