# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account deletion', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login(as = user)
    post session_path, params: { email_address: as.email_address, password: 'password123' }
  end

  def json(status: 200, **body)
    { status:, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  it 'offers the deletion form in the profile' do
    login
    get profile_path
    expect(response.body).to include('Usuń konto')
  end

  it 'keeps everything when the password is wrong' do
    login
    delete account_path, params: { password: 'nope' }

    expect(response).to redirect_to(profile_path)
    expect(flash[:alert]).to include('hasło')
    expect(User.exists?(user.id)).to be(true)
  end

  it 'deletes the account, its data and sessions, and logs out' do
    create(:diet, user: user)
    login
    delete account_path, params: { password: 'password123' }

    expect(response).to redirect_to(root_path)
    expect(response.headers['Clear-Site-Data']).to include('storage')
    expect(User.exists?(user.id)).to be(false)
    expect(Diet.where(user_id: user.id)).to be_empty
    expect(Session.where(user_id: user.id)).to be_empty
  end

  context 'with an active Pro subscription' do
    before { user.update!(subscription: :active, stripe_customer_id: 'cus_1') }

    let!(:list) do
      stub_request(:get, %r{api.stripe.com/v1/subscriptions\?.*customer=cus_1})
        .to_return(json(object: 'list', has_more: false,
                        data: [{ id: 'sub_1', object: 'subscription', status: 'active' },
                               { id: 'sub_0', object: 'subscription', status: 'canceled' }]))
    end
    let!(:cancel) do
      stub_request(:delete, 'https://api.stripe.com/v1/subscriptions/sub_1')
        .to_return(json(id: 'sub_1', object: 'subscription', status: 'canceled'))
    end

    it 'cancels the live subscription, deletes the account, then the Stripe customer' do
      customer = stub_request(:delete, 'https://api.stripe.com/v1/customers/cus_1')
                 .to_return(json(id: 'cus_1', object: 'customer', deleted: true))
      login
      delete account_path, params: { password: 'password123' }

      expect([list, cancel, customer]).to all(have_been_requested.once)
      expect(User.exists?(user.id)).to be(false)
    end

    it 'still deletes the account when removing the Stripe customer fails' do
      stub_request(:delete, 'https://api.stripe.com/v1/customers/cus_1').to_return(status: 500, body: '{}')
      login
      delete account_path, params: { password: 'password123' }

      expect(User.exists?(user.id)).to be(false)
    end

    it 'still deletes the account when the Stripe customer no longer exists (other env or removed in dashboard)' do
      missing = json(status: 404, error: { type: 'invalid_request_error', code: 'resource_missing',
                                           message: 'No such customer: cus_1' })
      stub_request(:get, %r{api.stripe.com/v1/subscriptions\?.*customer=cus_1}).to_return(missing)
      stub_request(:delete, 'https://api.stripe.com/v1/customers/cus_1').to_return(missing)
      login
      delete account_path, params: { password: 'password123' }

      expect(cancel).not_to have_been_requested
      expect(User.exists?(user.id)).to be(false)
    end

    it 'keeps the account when the subscription cannot be cancelled, so billing does not continue unseen' do
      stub_request(:delete, 'https://api.stripe.com/v1/subscriptions/sub_1').to_return(status: 500, body: '{}')
      login
      delete account_path, params: { password: 'password123' }

      expect(response).to redirect_to(profile_path)
      expect(flash[:alert]).to include('subskrypcj')
      expect(User.exists?(user.id)).to be(true)
    end
  end

  it 'keeps the account and explains when the database refuses the deletion' do
    allow_any_instance_of(User).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed) # rubocop:disable RSpec/AnyInstance
    login
    delete account_path, params: { password: 'password123' }

    expect(response).to redirect_to(profile_path)
    expect(flash[:alert]).to include('kontakt@asystentdiet.pl')
    expect(user.reload).to be_present
  end

  it 'returns a shared shopping-cart partner to their own cart' do
    partner = create(:user, password: 'password123', password_confirmation: 'password123')
    invitation = ShoppingCartInvitation.create!(inviter: user, invitee: partner)
    ShoppingCartSharingService.new(invitation).accept!
    login
    delete account_path, params: { password: 'password123' }

    expect(partner.reload.active_shopping_cart).to eq(partner.owned_shopping_cart)
  end
end
