# frozen_string_literal: true

Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key) || (Rails.env.test? ? 'sk_test_dummy' : nil)
Stripe.api_version = '2026-06-24.dahlia'

# In development `bin/dev` syncs the local `stripe listen` secret into .env as
# STRIPE_SIGNING_SECRET, so forwarded webhooks verify without editing credentials.
StripeEvent.signing_secret =
  (ENV['STRIPE_SIGNING_SECRET'].presence if Rails.env.development?) ||
  Rails.application.credentials.dig(:stripe, :signing_secret)

# StripeEvent.subscribe takes one event name (an array becomes a never-matching regexp).
StripeEvent.configure do |events|
  %w[checkout.session.completed checkout.session.async_payment_succeeded].each do |type|
    events.subscribe type, ->(event) { StripeWebhooks::CheckoutSessionCompleted.new.call(event) }
  end
  %w[customer.subscription.updated customer.subscription.deleted].each do |type|
    events.subscribe type, ->(event) { StripeWebhooks::SyncSubscription.new.call(event) }
  end
end
