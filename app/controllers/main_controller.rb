# frozen_string_literal: true

class MainController < ApplicationController
  allow_unauthenticated_access

  def index
    redirect_to diet_set_plans_path if authenticated?
  end
end
