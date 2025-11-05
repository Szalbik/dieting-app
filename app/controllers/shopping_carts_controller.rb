# frozen_string_literal: true

class ShoppingCartsController < ApplicationController
  UNDO_TIME_LIMIT = 30.minutes

  before_action :cleanup_expired_removal_records

  def show
    @shopping_cart = Current.user.shopping_cart
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
