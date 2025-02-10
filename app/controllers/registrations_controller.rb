# frozen_string_literal: true

class RegistrationsController < ApplicationController
  layout 'registration'

  # Include Authentication module unless it's already in ApplicationController
  # include Authentication
  allow_unauthenticated_access

  rate_limit to: 10,
    within: 3.minutes,
    only: :create,
    with: -> { redirect_to new_registration_url, alert: 'Try again later.' }

  def new
    @user = User.new
  end

  def create
    @user = User.new(safe_params)

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: 'Welcome!'
    else
      flash[:alert] = 'Email or password confirmation invalid.'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def safe_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
