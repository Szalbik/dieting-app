# frozen_string_literal: true

class PasswordsController < ApplicationController
  before_action :authenticate_user!

  def edit
  end

  def update
    if current_user.update(password_params)
      redirect_to products_path, notice: 'Password was successfully updated.'
    else
      flash.now[:error] = 'There was a problem updating the password.'
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user)
      .permit(:password, :password_confirmation, :password_challenge)
      .with_defaults(password_challenge: '')
  end
end
