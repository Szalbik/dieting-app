# frozen_string_literal: true

class RemoveShoppingCartItemsJob < ApplicationJob
  queue_as :default

  def perform(item_ids, user_id)
    user = User.find(user_id)
    items = ShoppingCartItem.where(id: item_ids, shopping_cart: user.shopping_cart)

    if items.any?
      items.destroy_all
      Rails.logger.info "Removed #{items.count} shopping cart items for user #{user_id}"
    else
      Rails.logger.warn "No shopping cart items found to remove for user #{user_id}"
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "User not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Error removing shopping cart items: #{e.message}"
    raise
  end

  def self.cancel_scheduled_jobs(item_ids, user_id)
    # Find and cancel any scheduled jobs for these specific items and user
    scheduled_jobs = SolidQueue::ScheduledExecution.joins(:job)
      .where('solid_queue_jobs.arguments @> ?', [item_ids, user_id].to_json)

    scheduled_jobs.each(&:destroy)

    Rails.logger.info "Cancelled #{scheduled_jobs.count} scheduled jobs for user #{user_id}"
  rescue StandardError => e
    Rails.logger.error "Error cancelling scheduled jobs: #{e.message}"
  end
end
