# frozen_string_literal: true

class MainController < ApplicationController
  allow_unauthenticated_access

  def index
    if authenticated?
      flash.keep
      redirect_to diet_set_plans_path
    end
  end
end
