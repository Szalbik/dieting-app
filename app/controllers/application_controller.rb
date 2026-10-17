# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  helper_method :payments_enabled?

  # ponytail: Stripe keys present = Pro checkout on; until then Pro shows as "wkrótce".
  def payments_enabled?
    Stripe.api_key.present?
  end

  private

  def require_admin!
    return if Current.user&.admin?

    redirect_to root_path, alert: 'Access denied.'
  end

  def ai_quota_exhausted_alert
    if Current.user.subscribed?
      "Wykorzystałeś #{helpers.ai_operations(User::AI_QUOTA_LIMITS.fetch(:pro))} w tym miesiącu. " \
        'Limit odnowi się 1. dnia przyszłego miesiąca.'
    else
      'Wykorzystałeś darmową operację AI. Przejdź na Pro, aby kontynuować.'
    end
  end

  # Todoist token lives in the session for 30 minutes (set in TodoistController#receive_code).
  def todoist_token
    token = session[:todoist_token]&.stringify_keys
    return if token.blank?
    return token if Time.zone.parse(token['expires_at'].to_s)&.future?

    session.delete(:todoist_token)
    nil
  end
end
