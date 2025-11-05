# frozen_string_literal: true

class ShoppingCartItemsController < ApplicationController
  UNDO_TIME_LIMIT = 30.minutes
  MAX_REMOVAL_RECORDS = 10 # Limit to prevent session cookie overflow

  before_action :cleanup_expired_removal_records, only: [:destroy, :undo]

  def destroy
    @product = Current.user.products.find(params[:id])
    shopping_cart = Current.user.shopping_cart

    items = shopping_cart.shopping_cart_items
      .joins(:product)
      .where(products: { name: @product.name })

    # Store item IDs for potential undo and background job
    item_ids = items.pluck(:id)

    removal_record = {
      item_ids: item_ids,
      removed_at: Time.current.to_i,
      product_name: @product.name,
      category_name: @product.category&.name || 'Inne',
    }

    session[:removed_items] = [] unless session[:removed_items].is_a?(Array)
    session[:removed_items] << removal_record

    # Limit the number of removal records to prevent session cookie overflow
    if session[:removed_items].length > MAX_REMOVAL_RECORDS
      # Keep only the most recent records
      session[:removed_items] = session[:removed_items].last(MAX_REMOVAL_RECORDS)
    end

    # Schedule background job to remove items from backend after delay
    RemoveShoppingCartItemsJob.set(wait: 30.minutes).perform_later(item_ids, Current.user.id)

    # Set flash message for user feedback
    flash[:success] = 'Produkt został usunięty z koszyka. Możesz cofnąć operację w ciągu 30 minut.'

    # Remove items from the shopping cart for immediate UI update
    items.destroy_all
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
        # Cancel the scheduled background job for these items
        item_ids = removal_record['item_ids'] || removal_record[:item_ids]
        RemoveShoppingCartItemsJob.cancel_scheduled_jobs(item_ids, Current.user.id)

        # Restore the items by recreating them
        product = Current.user.products.find_by(name: removal_record['product_name'] || removal_record[:product_name])
        if product
          shopping_cart = Current.user.shopping_cart
          shopping_cart.shopping_cart_items.create!(product: product)
        end

        @shopping_cart = Current.user.shopping_cart
        flash[:success] = 'Produkt został przywrócony do koszyka.'
      else
        # No valid removal record found
        flash[:warning] = 'No items to undo or undo time limit expired'
      end
    else
      flash[:info] = 'No items to undo'
    end
  end

  private

  def cleanup_expired_removal_records
    return unless session[:removed_items].is_a?(Array)

    current_time = Time.current
    session[:removed_items].reject! do |record|
      removed_at = Time.zone.at(record['removed_at'] || record[:removed_at])
      current_time - removed_at > UNDO_TIME_LIMIT
    end
  end

  def shopping_cart_item_params
    params.require(:shopping_cart_item).permit(:product_id, :quantity)
  end
end
