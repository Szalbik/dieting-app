# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StripeWebhooks::SyncSubscription do
  let!(:user) { create(:user, stripe_customer_id: 'cus_123') }

  # Since API "basil" current_period_end lives on subscription items, not on the subscription.
  def event_for(status:, cancel_at_period_end: false, cancel_at: nil, item_period_end: nil, customer: 'cus_123')
    object = { object: 'subscription', customer: customer, status: status, cancel_at_period_end: cancel_at_period_end,
               cancel_at: cancel_at,
               items: { object: 'list', data: [{ object: 'subscription_item', current_period_end: item_period_end }] } }
    Stripe::Event.construct_from(type: 'customer.subscription.updated', data: { object: object })
  end

  it 'activates the subscription when active and not scheduled for cancellation' do
    described_class.new.call(event_for(status: 'active'))
    expect(user.reload).to be_subscribed
    expect(user.subscription_end_date).to be_nil
  end

  it 'sets an end date when active but cancel_at_period_end is set' do
    cancel_at = 30.days.from_now.to_i
    described_class.new.call(event_for(status: 'active', cancel_at_period_end: true, cancel_at: cancel_at))
    user.reload
    expect(user).to be_subscribed
    expect(user.subscription_end_date.to_i).to eq(cancel_at)
  end

  it 'falls back to the item period end when cancel_at is absent' do
    period_end = 20.days.from_now.to_i
    described_class.new.call(event_for(status: 'active', cancel_at_period_end: true, item_period_end: period_end))
    expect(user.reload.subscription_end_date.to_i).to eq(period_end)
  end

  it 'keeps Pro while a failed renewal is being retried (past_due)' do
    user.update!(subscription: :active)
    described_class.new.call(event_for(status: 'past_due'))
    expect(user.reload).to be_subscription_active
  end

  it 'leaves state untouched for an incomplete first payment' do
    described_class.new.call(event_for(status: 'incomplete'))
    expect(user.reload).not_to be_subscribed
  end

  %w[canceled unpaid incomplete_expired].each do |status|
    it "deactivates the subscription when #{status}" do
      user.update!(subscription: :active, subscription_end_date: 3.days.from_now)
      described_class.new.call(event_for(status: status))
      expect(user.reload).not_to be_subscribed
    end
  end

  it 'ignores customers we do not know (no 500 → no Stripe retry storm)' do
    expect { described_class.new.call(event_for(status: 'active', customer: 'cus_unknown')) }.not_to raise_error
    expect(user.reload).not_to be_subscribed
  end
end
