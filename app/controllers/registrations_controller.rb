# frozen_string_literal: true

class RegistrationsController < ApplicationController
  layout 'authentication'

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

    unless params[:terms] == '1'
      flash.now[:alert] = 'Musisz potwierdzić, że masz ukończone 18 lat, i zaakceptować Regulamin oraz Politykę prywatności.'
      render :new, status: :unprocessable_entity
      return
    end

    @user.record_consent(:terms)
    @user.consents = @user.consents.merge('terms_version' => LegalDocuments::VERSION)

    if @user.save
      start_new_session_for @user
      redirect_to(params[:plan] == 'pro' ? upgrade_path : after_authentication_url, notice: 'Welcome!')
    else
      # Never confirm that an address already has an account (the generic flash covers it).
      @user.errors.delete(:email_address, :taken)
      flash[:alert] = 'Email or password confirmation invalid.'
      render :new, status: :unprocessable_entity
    end
  end

  private

  def safe_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
