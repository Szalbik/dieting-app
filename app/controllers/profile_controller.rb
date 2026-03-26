# frozen_string_literal: true

class ProfileController < ApplicationController
  def show
    @shopping_cart_partner = Current.user.shopping_cart_partner
    @received_shopping_cart_invitations = Current.user.received_shopping_cart_invitations.pending
      .includes(:inviter)
      .order(created_at: :desc)
    @sent_shopping_cart_invitations = Current.user.sent_shopping_cart_invitations.pending
      .includes(:invitee)
      .order(created_at: :desc)
    @shopping_cart_invitation_history = ShoppingCartInvitation.involving(Current.user)
      .includes(:inviter, :invitee)
      .order(updated_at: :desc)
  end
end
