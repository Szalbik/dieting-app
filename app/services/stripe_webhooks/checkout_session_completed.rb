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
      confirm_purchase(user, session)
    end

    private

    # Art. 21 ust. 1 upk: confirmation on a durable medium, once per session — completed and
    # async_payment_succeeded (BLIK) or a Stripe retry can all reach here for the same session.
    def confirm_purchase(user, session)
      return if user.consents.dig('pro_early_start', 'session') == session.id

      early_start = { 'at' => Time.current.iso8601, 'session' => session.id, 'terms_version' => LegalDocuments::VERSION }
      user.update_column(:consents, user.consents.merge('pro_early_start' => early_start)) # rubocop:disable Rails/SkipsModelValidations
      SubscriptionMailer.confirmation(user, interval: session.metadata&.[]('interval'),
                                            amount_total: session.amount_total).deliver_later
    end
  end
end
