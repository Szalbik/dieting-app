# frozen_string_literal: true

# Nightly retention promised by the privacy policy: PDF blobs no diet points to any more (deleted
# diets/accounts from before purge_later, failed uploads), products left behind by deleted diets,
# login sessions older than 12 months and dietitian waitlist entries older than 2 years.
# ponytail: Session rows are never touched after login, so created_at = "zalogowanie" in the policy.
class DataRetentionJob < ApplicationJob
  queue_as :default

  ORPHAN_GRACE = 1.day # an upload attaches within the request; older unattached blobs are leftovers
  SESSION_TTL = 12.months
  WAITLIST_TTL = 2.years

  def perform
    ActiveStorage::Blob.unattached.where(created_at: ...ORPHAN_GRACE.ago).find_each(&:purge)
    Session.where(created_at: ...SESSION_TTL.ago).delete_all
    DietitianWaitlistEntry.where(created_at: ...WAITLIST_TTL.ago).delete_all
    orphaned_products.find_each(&:destroy)
  end

  private

  # Meal/DietSet nullify their products on destroy (dependent: :destroy would hit the products FK of
  # shopping_cart_items before the meals → meal_plans → items cascade runs), so sweep them here.
  # Skip any a cart item (even soft-deleted) or plan substitution still points at.
  def orphaned_products
    Product.orphaned
      .where.not(id: ShoppingCartItem.with_deleted.select(:product_id))
      .where.not(id: MealPlanProductSubstitution.select(:product_id))
  end
end
