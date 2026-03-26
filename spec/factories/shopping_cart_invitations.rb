# frozen_string_literal: true

FactoryBot.define do
  factory(:shopping_cart_invitation) do
    association :inviter, factory: :user
    association :invitee, factory: :user
    status { :pending }
  end
end
