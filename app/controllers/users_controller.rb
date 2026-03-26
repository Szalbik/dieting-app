# frozen_string_literal: true

class UsersController < ApplicationController
  def update
    if Current.user.update(user_params)
      redirect_to profile_path, notice: 'Your data was updated successfully.'
    else
      load_profile_context
      flash.now[:error] = 'There was and error.'
      render 'profile/show', status: :unprocessable_entity
    end
  end

  private

  def load_profile_context
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

  def user_params
    params.require(:user).permit(:email_address, :first_name)
  end
end
