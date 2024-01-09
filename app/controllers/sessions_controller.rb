# frozen_string_literal: true

class SessionsController < ApplicationController
  layout 'session'

  def new
    @user = User.new
  end

  def create
    if @user = User.authenticate_by(email: session_params[:email], password: session_params[:password])
      login @user
      redirect_to diets_path, notice: 'You have been logged in.'
    else
      flash.now[:error] = 'There was a problem logging in.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: 'You have been logged out.'
  end

  private

  def session_params
    params.require(:user).permit(:email, :password)
  end
end
