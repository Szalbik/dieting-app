# frozen_string_literal: true

class CustomCartItemsController < ApplicationController
  def create
    @shopping_cart = Current.user.shopping_cart
    # A replayed offline add carries the same client_id: answer as if created, insert nothing.
    @custom_item = replayed_item || @shopping_cart.custom_cart_items.build(custom_cart_item_params)

    if @custom_item.persisted? || save_once(@custom_item)
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
    bought = params[:bought].present? ? ActiveModel::Type::Boolean.new.cast(params[:bought]) == true : !custom_item.bought
    custom_item.update(bought: bought) # after_commit broadcasts to the shared cart

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
    params.require(:custom_cart_item).permit(:name, :quantity, :unit, :client_id)
  end

  def replayed_item
    client_id = custom_cart_item_params[:client_id].presence
    client_id && @shopping_cart.custom_cart_items.find_by(client_id: client_id)
  end

  # Two replays racing past replayed_item hit the unique index; the loser is still a success.
  def save_once(item)
    item.save
  rescue ActiveRecord::RecordNotUnique
    @custom_item = @shopping_cart.custom_cart_items.find_by!(client_id: item.client_id)
  end
end
