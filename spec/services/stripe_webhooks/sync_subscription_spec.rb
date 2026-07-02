# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StripeWebhooks::SyncSubscription do
  let!(:user) { create(:user, stripe_customer_id: 'cus_123') }

  def event_for(status:, cancel_at_period_end: false, cancel_at: nil, current_period_end: nil, customer: 'cus_123')
    object = { object: 'subscription', customer: customer, status: status, cancel_at_period_end: cancel_at_period_end,
               cancel_at: cancel_at, current_period_end: current_period_end }
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

  it 'deactivates the subscription when the status is not active (e.g. deleted or past_due)' do
    user.update!(subscription: :active)
    described_class.new.call(event_for(status: 'canceled'))
    expect(user.reload).not_to be_subscribed
  end

  it 'raises when no user matches the customer id' do
    expect { described_class.new.call(event_for(status: 'active', customer: 'cus_unknown')) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
