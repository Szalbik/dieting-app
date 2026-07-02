# frozen_string_literal: true

module StripeWebhooks
  class SyncSubscription
    def call(event)
      subscription = event.data.object
      user = User.find_by!(stripe_customer_id: subscription.customer)

      if subscription.status == 'active' && !subscription.cancel_at_period_end
        user.update!(subscription: :active, subscription_end_date: nil)
      elsif subscription.status == 'active' && subscription.cancel_at_period_end
        end_date = Time.zone.at(subscription.cancel_at || subscription.current_period_end)
        user.update!(subscription: :active, subscription_end_date: end_date)
      else
        user.update!(subscription: :inactive, subscription_end_date: nil)
      end
    end
  end
end
