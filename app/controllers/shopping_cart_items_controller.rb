# frozen_string_literal: true

class ShoppingCartItemsController < ApplicationController
  UNDO_TIME_LIMIT = 30.minutes

  def destroy
    @product = Current.user.products.find(params[:id])
    shopping_cart = Current.user.shopping_cart

    items = shopping_cart.shopping_cart_items
      .joins(:product)
      .where(products: { name: @product.name })

    removal_record = {
      item_ids: items.pluck(:id),
      removed_at: Time.current.to_i,
    }

    session[:removed_items] ||= []
    session[:removed_items] << removal_record

    items.each(&:destroy)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shopping_cart_path }
    end
  end

  def undo
    if session[:removed_items].present?
      removal_record = nil

      # Check the most recent removal records until a valid one is found.
      while session[:removed_items].present? && removal_record.nil?
        candidate = session[:removed_items].last
        removed_at = Time.at(candidate['removed_at'] || candidate[:removed_at])
        if Time.current - removed_at <= UNDO_TIME_LIMIT
          removal_record = candidate
          session[:removed_items].pop
        else
          # Remove expired record and check next.
          session[:removed_items].pop
        end
      end

      if removal_record.present?
        ShoppingCartItem.only_deleted.where(id: removal_record['item_ids'] || removal_record[:item_ids]).each(&:restore)
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
