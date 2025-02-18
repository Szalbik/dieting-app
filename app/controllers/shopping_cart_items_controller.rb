# frozen_string_literal: true

class ShoppingCartItemsController < ApplicationController
  # Define the undo window, e.g. 5 minutes.
  UNDO_TIME_LIMIT = 5.minutes

  def destroy
    @product = Current.user.products.find(params[:id])
    shopping_cart = Current.user.shopping_cart

    # Find all shopping cart items for this product (by name).
    items = shopping_cart.shopping_cart_items
      .joins(:product)
      .where(products: { name: @product.name })

    # Store the removed items' attributes and a timestamp in the session.
    session[:removed_items] = {
      items: items.map { |item| item.attributes },
      removed_at: Time.current.to_i,
    }

    # Delete the items.
    items.destroy_all

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shopping_cart_path }
    end
  end

  def undo
    if session[:removed_items].present?
      removed_data = session.delete(:removed_items)
      removed_at = Time.at(removed_data['removed_at'] || removed_data[:removed_at])

      if Time.current - removed_at <= UNDO_TIME_LIMIT
        shopping_cart = Current.user.shopping_cart

        removed_data['items'].each do |attrs|
          # Re-create the shopping cart item without id and timestamp attributes.
          shopping_cart.shopping_cart_items.create!(attrs.except('id', 'created_at', 'updated_at'))
        end

        flash[:notice] = 'Cofnięto usunięcie produktu.'
      else
        flash[:alert] = 'Czas na cofnięcie operacji minął.'
      end
    else
      flash[:alert] = 'Brak operacji do cofnięcia.'
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update('shopping_cart', partial: 'shopping_carts/shopping_cart',
          locals: { shopping_cart: Current.user.shopping_cart }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash }),
        ]
      end
      format.html { redirect_to shopping_cart_path }
    end
  end
end
