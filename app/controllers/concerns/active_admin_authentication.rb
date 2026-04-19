# frozen_string_literal: true

module ActiveAdminAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :active_admin_current_user
  end

  def authenticate_active_admin_user!
    resume_active_admin_session
    return if Current.user&.admin?

    if Current.user.present?
      redirect_to root_path, alert: 'You are not authorized to access the admin panel.'
    else
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path, alert: 'Please sign in to access the admin panel.'
    end
  end

  def active_admin_current_user
    resume_active_admin_session
    Current.user
  end

  def handle_active_admin_unauthorized(_exception)
    redirect_to root_path, alert: 'You are not authorized to access the admin panel.'
  end

  private

  def resume_active_admin_session
    return Current.session if Current.session.present?
    return unless cookies.signed[:session_id]

    Current.session = Session.find_by(id: cookies.signed[:session_id])
  end
end
