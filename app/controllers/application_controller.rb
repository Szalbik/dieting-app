# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  helper_method :payments_enabled?

  # ponytail: Stripe keys present = Pro checkout on; until then Pro shows as "wkrótce".
  def payments_enabled?
    Stripe.api_key.present?
  end
end
