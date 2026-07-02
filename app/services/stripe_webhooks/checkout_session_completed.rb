# frozen_string_literal: true

module StripeWebhooks
  class CheckoutSessionCompleted
    def call(event)
      session = event.data.object
      return unless session.mode == 'subscription'

      user = User.find_by!(stripe_customer_id: session.customer)
      user.update!(subscription: :active, subscription_end_date: nil)
    end
  end
end
