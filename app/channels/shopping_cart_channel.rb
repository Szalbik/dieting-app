# frozen_string_literal: true

# Turbo stream channel for the live shopping list. Stock Turbo::StreamsChannel
# only checks the signature, so a partner removed from a shared cart could keep
# listening with a saved stream name; here every subscription re-checks membership.
class ShoppingCartChannel < ApplicationCable::Channel
  extend Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    stream_name = verified_stream_name_from_params
    cart = stream_name && GlobalID::Locator.locate(stream_name)

    if cart.is_a?(ShoppingCart) && cart.member_users.include?(current_user)
      stream_from stream_name
    else
      reject
    end
  rescue StandardError
    reject
  end
end
