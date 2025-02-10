# frozen_string_literal: true

class MainController < ApplicationController
  before_action :user_authenticated?

  def index;end

  private

  def user_authenticated?
    redirect_to meal_plans_path if user_signed_in?
  end
end
