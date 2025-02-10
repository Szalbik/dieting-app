# frozen_string_literal: true

class NavbarComponent < ViewComponent::Base
  attr_reader :current_user

  def initialize(current_user:)
    @current_user = Current.user
  end
end
