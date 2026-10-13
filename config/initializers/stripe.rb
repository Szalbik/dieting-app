# frozen_string_literal: true

Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key) || (Rails.env.test? ? 'sk_test_dummy' : nil)
Stripe.api_version = '2026-06-24.dahlia'

# In development `bin/dev` syncs the local `stripe listen` secret into .env as
# STRIPE_SIGNING_SECRET, so forwarded webhooks verify without editing credentials.
StripeEvent.signing_secret =
  (ENV['STRIPE_SIGNING_SECRET'].presence if Rails.env.development?) ||
  Rails.application.credentials.dig(:stripe, :signing_secret)

StripeEvent.configure do |events|
  events.subscribe 'checkout.session.completed', ->(event) { StripeWebhooks::CheckoutSessionCompleted.new.call(event) }
  events.subscribe %w[customer.subscription.updated customer.subscription.deleted],
                   ->(event) { StripeWebhooks::SyncSubscription.new.call(event) }
end
