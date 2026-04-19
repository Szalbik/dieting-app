# frozen_string_literal: true

class RemoveShoppingCartItemsJob < ApplicationJob
  queue_as :default

  def self.cancel_scheduled_jobs(item_ids, user_id)
    scheduled_jobs = SolidQueue::ScheduledExecution.joins(:job)
      .where('solid_queue_jobs.arguments @> ?', [item_ids, user_id].to_json)

    scheduled_jobs.each(&:destroy)
  rescue StandardError => e
    Rails.logger.error "Error cancelling scheduled jobs: #{e.message}"
  end

  def perform(item_ids, user_id)
    user = User.find(user_id)
    items = ShoppingCartItem.only_deleted
      .where(id: item_ids, shopping_cart: user.shopping_cart)

    dates_affected = items.pluck(:date).uniq

    if items.any?
      count = items.count
      items.each(&:really_destroy!)
      Rails.logger.info "Hard-deleted #{count} shopping cart items for user #{user_id}"
    end

    mark_shopping_done_for_completed_dates!(user: user, dates: dates_affected)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "User not found: #{e.message}"
  end

  private

  def mark_shopping_done_for_completed_dates!(user:, dates:)
    return if dates.empty?

    dates.each do |date|
      next if user.shopping_cart.shopping_cart_items.where(date: date).exists?

      DietSetPlan
        .joins(:diet)
        .where(diets: { user_id: user.id })
        .where(date: date)
        .update_all(shopping_done: true)
    end
  end
end
