# frozen_string_literal: true

class MainController < ApplicationController
  allow_unauthenticated_access

  def index
    redirect_to meal_plans_path if authenticated?
  end
end
