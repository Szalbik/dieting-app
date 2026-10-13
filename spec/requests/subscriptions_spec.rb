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
    it 'shows the plan, recurring terms and BLIK banks without touching Stripe' do
      login
      get upgrade_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('19,90 zł', '199 zł', 'odnawia się automatycznie', 'PKO BP', terms_path)
      expect(response.body).to include('name="interval" value="monthly"', 'name="interval" value="yearly"')
      expect(WebMock).not_to have_requested(:any, /api.stripe.com/)
    end

    it 'redirects to profile when payments are not configured' do
      allow(Stripe).to receive(:api_key).and_return(nil)
      login
      get upgrade_path
      expect(response).to redirect_to(profile_path)
    end

    it 'redirects to profile when already subscribed' do
      user.update!(subscription: :active)
      login
      get upgrade_path
      expect(response).to redirect_to(profile_path)
    end

    it 'redirects to profile for a lifetime user' do
      user.update!(subscription: :lifetime)
      login
      get upgrade_path
      expect(response).to redirect_to(profile_path)
    end
  end

  describe 'POST /upgrade' do
    it 'creates a Stripe customer and checkout session, then redirects to it' do
      stub_request(:post, 'https://api.stripe.com/v1/customers')
        .to_return(json_response(id: 'cus_123', email: user.email_address))
      session_request = stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
                        .with(body: hash_including('mode' => 'subscription',
                                                   'managed_payments' => { 'enabled' => 'false' },
                                                   'excluded_payment_method_types' => ['klarna']))
                        .to_return(json_response(id: 'cs_123', url: 'https://checkout.stripe.com/pay/cs_123'))

      login
      post upgrade_path

      expect(session_request).to have_been_requested
      expect(response).to redirect_to('https://checkout.stripe.com/pay/cs_123')
      expect(user.reload.stripe_customer_id).to eq('cus_123')
    end

    it 'uses the yearly price for interval=yearly' do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:stripe, :yearly_price_id).and_return('price_yearly')
      stub_request(:post, 'https://api.stripe.com/v1/customers').to_return(json_response(id: 'cus_123'))
      yearly = stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
               .with(body: hash_including('line_items' => [{ 'price' => 'price_yearly', 'quantity' => '1' }]))
               .to_return(json_response(id: 'cs_1', url: 'https://checkout.stripe.com/pay/cs_1'))

      login
      post upgrade_path, params: { interval: 'yearly' }

      expect(yearly).to have_been_requested
    end

    it 'falls back to the monthly price for an unknown interval' do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:stripe, :monthly_price_id).and_return('price_monthly')
      stub_request(:post, 'https://api.stripe.com/v1/customers').to_return(json_response(id: 'cus_123'))
      monthly = stub_request(:post, 'https://api.stripe.com/v1/checkout/sessions')
                .with(body: hash_including('line_items' => [{ 'price' => 'price_monthly', 'quantity' => '1' }]))
                .to_return(json_response(id: 'cs_1', url: 'https://checkout.stripe.com/pay/cs_1'))

      login
      post upgrade_path, params: { interval: 'weekly' }

      expect(monthly).to have_been_requested
    end

    it 'redirects to profile without hitting Stripe when already subscribed' do
      user.update!(subscription: :active)
      login
      post upgrade_path
      expect(response).to redirect_to(profile_path)
      expect(WebMock).not_to have_requested(:any, /api.stripe.com/)
    end
  end

  describe 'profile subscription button' do
    it 'offers Pro to a user who abandoned checkout (has a Stripe customer, no subscription)' do
      user.update!(stripe_customer_id: 'cus_123')
      login
      get profile_path
      expect(response.body).to include("Przejdź na Pro — 19,90 zł/mies.")
      expect(response.body).not_to include('Zarządzaj subskrypcją')
    end

    it 'offers the billing portal to a subscriber' do
      user.update!(stripe_customer_id: 'cus_123', subscription: :active)
      login
      get profile_path
      portal_form = Nokogiri::HTML(response.body).at_css("form[action='#{billing_portal_path}']")
      expect(portal_form['data-turbo']).to eq('false') # off-site redirect; Turbo fetch would hit CORS
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
