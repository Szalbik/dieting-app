# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingCartChannel, type: :channel do
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }
  let(:cart) { alice.owned_shopping_cart }
  let(:signed_name) { Turbo::StreamsChannel.signed_stream_name(cart) }

  it 'confirms a current member of the cart' do
    bob.update!(active_shopping_cart: cart)
    stub_connection current_user: bob

    subscribe(signed_stream_name: signed_name)

    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_from(cart.to_gid_param)
  end

  it 'rejects a user who is no longer a member, even with a valid signed stream name' do
    stub_connection current_user: bob

    subscribe(signed_stream_name: signed_name)

    expect(subscription).to be_rejected
  end

  it 'rejects a tampered stream name' do
    stub_connection current_user: alice

    subscribe(signed_stream_name: 'not-signed')

    expect(subscription).to be_rejected
  end
end
