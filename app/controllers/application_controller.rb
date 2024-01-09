# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_currrent_attributes

  private

  def authenticate_user!
    redirect_to new_session_path, alert: 'You must be logged in to access this page.' unless user_signed_in?
  end

  def current_user
    Current.user ||= authenticate_user_from_session
  end
  helper_method :current_user

  def authenticate_user_from_session
    User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end
  helper_method :user_signed_in?

  def login(user)
    Current.user = @user
    reset_session
    session[:user_id] = @user.id
  end

  def logout
    Current.user = nil
    reset_session
  end

  def set_currrent_attributes
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
  end
end
