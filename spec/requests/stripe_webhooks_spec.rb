# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stripe webhooks', type: :request do
  let(:secret) { 'whsec_test_secret' }
  let!(:user) { create(:user, stripe_customer_id: 'cus_123') }
  let(:paid_session) do
    { object: 'checkout.session', mode: 'subscription', customer: 'cus_123', payment_status: 'paid' }
  end

  around do |example|
    previous = StripeEvent.signing_secrets
    StripeEvent.signing_secret = secret
    example.run
  ensure
    StripeEvent.signing_secrets = previous
  end

  def post_event(event_type, object, signing_secret: secret)
    payload = { id: "evt_#{SecureRandom.hex(4)}", object: 'event', type: event_type, data: { object: object } }.to_json
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(Time.zone.at(timestamp), payload, signing_secret)
    post '/stripe_webhooks', params: payload,
                             headers: { 'Content-Type' => 'application/json',
                                        'Stripe-Signature' => "t=#{timestamp},v1=#{signature}" }
  end

  it 'activates Pro on a correctly signed checkout.session.completed' do
    post_event('checkout.session.completed', paid_session)
    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_subscribed
  end

  it 'activates Pro when a delayed payment succeeds' do
    post_event('checkout.session.async_payment_succeeded', paid_session)
    expect(user.reload).to be_subscribed
  end

  it 'ends Pro on customer.subscription.deleted' do
    user.update!(subscription: :active)
    post_event('customer.subscription.deleted',
               { object: 'subscription', customer: 'cus_123', status: 'canceled', cancel_at_period_end: false,
                 cancel_at: nil, items: { object: 'list', data: [] } })
    expect(user.reload).not_to be_subscribed
  end

  it 'rejects a payload signed with another secret' do
    post_event('checkout.session.completed', paid_session, signing_secret: 'whsec_wrong')
    expect(response).to have_http_status(:bad_request)
    expect(user.reload).not_to be_subscribed
  end
end
