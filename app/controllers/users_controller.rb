# frozen_string_literal: true

class UsersController < ApplicationController
  def update
    attrs = user_params
    old_email = Current.user.email_address
    email_change = attrs[:email_address].present? && attrs[:email_address] != old_email

    # Changing the address is an account-takeover lever (reset mail goes to the new one): re-authenticate.
    if email_change && !Current.user.authenticate(params[:current_password].to_s)
      render_profile_error('Podaj aktualne hasło, aby zmienić adres e-mail.')
      return
    end

    if Current.user.update(attrs)
      if email_change
        Current.user.sessions.where.not(id: Current.session.id).destroy_all
        AccountMailer.email_changed(Current.user, old_email).deliver_later
      end
      redirect_to profile_path, notice: 'Your data was updated successfully.'
    else
      render_profile_error('There was and error.')
    end
  end

  private

  def render_profile_error(message)
    load_profile_context
    flash.now[:error] = message
    render 'profile/show', status: :unprocessable_entity
  end

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
