# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Subscriptions', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  def json_response(body)
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  describe 'GET /upgrade' do
    it 'creates a Stripe customer and checkout session, then redirects to it' do
      stub_request(:post, 'https://api.stripe.com/v1/customers')
        .to_return(json_response(id: 'cus_123', email: user.email_address))
      stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
        .to_return(json_response(id: 'cs_123', url: 'https://checkout.stripe.com/pay/cs_123', mode: 'subscription'))

      login
      get upgrade_path

      expect(response).to redirect_to('https://checkout.stripe.com/pay/cs_123')
      expect(user.reload.stripe_customer_id).to eq('cus_123')
    end

    it 'redirects to profile without hitting Stripe when already subscribed' do
      user.update!(subscription: :active)
      login
      get upgrade_path
      expect(response).to redirect_to(profile_path)
    end

    it 'redirects to profile without hitting Stripe for a lifetime user' do
      user.update!(subscription: :lifetime)
      login
      get upgrade_path
      expect(response).to redirect_to(profile_path)
    end
  end

  describe 'POST /billing_portal' do
    it 'creates a billing portal session and redirects to it' do
      user.update!(stripe_customer_id: 'cus_123')
      stub_request(:get, 'https://api.stripe.com/v1/customers/cus_123')
        .to_return(json_response(id: 'cus_123', email: user.email_address))
      stub_request(:post, 'https://api.stripe.com/v1/billing_portal/sessions')
        .to_return(json_response(id: 'bps_123', url: 'https://billing.stripe.com/session/bps_123'))

      login
      post billing_portal_path

      expect(response).to redirect_to('https://billing.stripe.com/session/bps_123')
    end
  end
end
