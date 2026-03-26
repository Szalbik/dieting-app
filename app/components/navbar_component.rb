# frozen_string_literal: true

class NavbarComponent < ViewComponent::Base
  attr_reader :current_user

  def initialize(current_user:)
    @current_user = Current.user
  end

  def shared_shopping_cart?
    current_user&.shopping_cart&.shared?
  end

  def shopping_cart_partner_label
    return if current_user.blank?

    partner = current_user.shopping_cart_partner
    partner&.first_name.presence || partner&.email_address
  end
end
