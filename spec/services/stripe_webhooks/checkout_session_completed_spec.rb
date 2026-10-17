# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StripeWebhooks::CheckoutSessionCompleted do
  let!(:user) { create(:user, stripe_customer_id: 'cus_123') }

  def event_for(mode: 'subscription', customer: 'cus_123', payment_status: 'paid', id: 'cs_1')
    Stripe::Event.construct_from(
      type: 'checkout.session.completed',
      data: { object: { object: 'checkout.session', id: id, mode: mode, customer: customer,
                        payment_status: payment_status, amount_total: 1990, metadata: { interval: 'monthly' },
                        consent: { terms_of_service: 'accepted' } } }
    )
  end

  it 'activates the subscription for a subscription-mode session' do
    described_class.new.call(event_for)
    expect(user.reload).to be_subscribed
    expect(user.subscription_end_date).to be_nil
  end

  it 'waits for payment when the session is still unpaid (delayed methods)' do
    described_class.new.call(event_for(payment_status: 'unpaid'))
    expect(user.reload).not_to be_subscribed
  end

  it 'ignores one-time payment sessions' do
    described_class.new.call(event_for(mode: 'payment'))
    expect(user.reload).not_to be_subscribed
  end

  it 'ignores customers we do not know (no 500 → no Stripe retry storm)' do
    expect { described_class.new.call(event_for(customer: 'cus_unknown')) }.not_to raise_error
    expect(user.reload).not_to be_subscribed
  end

  describe 'purchase confirmation (art. 21 upk)' do
    include ActiveJob::TestHelper

    it 'records the early-start request and mails the confirmation once per session' do
      expect do
        described_class.new.call(event_for)
        described_class.new.call(event_for) # async_payment_succeeded / Stripe retry for the same session
      end.to have_enqueued_mail(SubscriptionMailer, :confirmation).once
      expect(user.reload.consents.dig('pro_early_start', 'session')).to eq('cs_1')
    end

    it 'mails again for a later, separate purchase' do
      described_class.new.call(event_for)
      expect { described_class.new.call(event_for(id: 'cs_2')) }
        .to have_enqueued_mail(SubscriptionMailer, :confirmation)
    end

    it 'leaves the session unmarked when the mail cannot be queued, so the Stripe retry sends it' do
      allow(SubscriptionMailer).to receive(:confirmation).and_raise(ActiveRecord::StatementInvalid, 'busy')
      expect { described_class.new.call(event_for) }.to raise_error(ActiveRecord::StatementInvalid)
      expect(user.reload.consents).not_to have_key('pro_early_start')
    end

    it 'does not mail while the payment is pending' do
      expect { described_class.new.call(event_for(payment_status: 'unpaid')) }
        .not_to have_enqueued_mail(SubscriptionMailer, :confirmation)
    end
  end
end
