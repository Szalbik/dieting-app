# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StripeWebhooks::CheckoutSessionCompleted do
  let!(:user) { create(:user, stripe_customer_id: 'cus_123') }

  def event_for(mode: 'subscription', customer: 'cus_123')
    Stripe::Event.construct_from(
      type: 'checkout.session.completed',
      data: { object: { object: 'checkout.session', mode: mode, customer: customer } }
    )
  end

  it 'activates the subscription for a subscription-mode session' do
    described_class.new.call(event_for)
    expect(user.reload).to be_subscribed
    expect(user.subscription_end_date).to be_nil
  end

  it 'ignores one-time payment sessions' do
    described_class.new.call(event_for(mode: 'payment'))
    expect(user.reload).not_to be_subscribed
  end

  it 'ignores customers we do not know (no 500 → no Stripe retry storm)' do
    expect { described_class.new.call(event_for(customer: 'cus_unknown')) }.not_to raise_error
    expect(user.reload).not_to be_subscribed
  end
end
