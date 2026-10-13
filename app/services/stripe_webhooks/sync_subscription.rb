# frozen_string_literal: true

module StripeWebhooks
  class SyncSubscription
    ENDED_STATUSES = %w[canceled unpaid incomplete_expired].freeze

    def call(event)
      subscription = event.data.object
      user = User.find_by(stripe_customer_id: subscription.customer)
      return unless user # customer from another env / test mode

      case subscription.status
      when 'active', 'trialing' then sync_active(user, subscription)
      when *ENDED_STATUSES then user.update!(subscription: :inactive, subscription_end_date: nil)
      end
      # past_due: Stripe is retrying a failed renewal — Pro stays until it ends as unpaid/canceled.
      # incomplete: first payment not confirmed yet — checkout.session events decide.
    end

    private

    def sync_active(user, subscription)
      if subscription.cancel_at_period_end || subscription.cancel_at
        user.update!(subscription: :active, subscription_end_date: Time.zone.at(period_end(subscription)))
      else
        user.update!(subscription: :active, subscription_end_date: nil)
      end
    end

    # Since API "basil" the period end lives on subscription items, not on the subscription.
    def period_end(subscription)
      subscription.cancel_at || subscription.items.data.first.current_period_end
    end
  end
end
