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

  # Todoist token lives in the session for 30 minutes (set in TodoistController#receive_code).
  def todoist_token
    token = session[:todoist_token]&.stringify_keys
    return if token.blank?
    return token if Time.zone.parse(token['expires_at'].to_s)&.future?

    session.delete(:todoist_token)
    nil
  end
end
