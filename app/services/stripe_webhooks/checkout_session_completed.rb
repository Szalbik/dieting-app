# frozen_string_literal: true

module StripeWebhooks
  # Handles checkout.session.completed and checkout.session.async_payment_succeeded.
  # Delayed methods complete the session as `unpaid` first; the async event follows once paid.
  class CheckoutSessionCompleted
    PAID_STATUSES = %w[paid no_payment_required].freeze

    def call(event)
      session = event.data.object
      return unless session.mode == 'subscription'
      return unless PAID_STATUSES.include?(session.payment_status)

      user = User.find_by(stripe_customer_id: session.customer)
      return unless user # customer from another env / test mode

      user.update!(subscription: :active, subscription_end_date: nil)
    end
  end
end
