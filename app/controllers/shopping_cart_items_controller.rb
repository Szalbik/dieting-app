# frozen_string_literal: true

class ShoppingCartItemsController < ApplicationController
  UNDO_TIME_LIMIT = 30.minutes
  MAX_REMOVAL_RECORDS = 10

  before_action :cleanup_expired_removal_records, only: [:destroy, :undo]

  def destroy
    shopping_cart = Current.user.shopping_cart
    product = Product.joins(:shopping_cart_items)
      .where(shopping_cart_items: { shopping_cart_id: shopping_cart.id })
      .find_by(id: params[:id])

    if product.nil?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("shopping_cart",
            partial: "shopping_carts/shopping_cart",
            locals: { shopping_cart: shopping_cart })
        end
        format.html { redirect_to shopping_cart_path }
      end
      return
    end

    group_key = product.shopping_cart_group_key
    items = shopping_cart.shopping_cart_items
      .includes(product: [:category, :canonical_product])
      .select { |item| item.product.shopping_cart_group_key == group_key }

    item_ids = items.map(&:id)
    group_name = Product.best_shopping_list_display_name(items.map(&:product))

    session[:removed_items] = [] unless session[:removed_items].is_a?(Array)
    session[:removed_items] << { item_ids: item_ids, removed_at: Time.current.to_i, product_name: group_name }
    session[:removed_items] = session[:removed_items].last(MAX_REMOVAL_RECORDS)

    RemoveShoppingCartItemsJob.set(wait: UNDO_TIME_LIMIT).perform_later(item_ids, Current.user.id)
    ShoppingCartItem.where(id: item_ids).destroy_all

    @removed_product_name = group_name

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shopping_cart_path }
    end
  end

  def undo
    @restored = false

    if session[:removed_items].present?
      cleanup_expired_removal_records
      removal_record = session[:removed_items]&.pop

      if removal_record.present?
        item_ids = removal_record['item_ids'] || removal_record[:item_ids]
        RemoveShoppingCartItemsJob.cancel_scheduled_jobs(item_ids, Current.user.id)
        ShoppingCartItem.only_deleted.where(id: item_ids).each(&:restore)
        @restored = true
      end
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to shopping_cart_path }
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
end
