# frozen_string_literal: true

# Base controller for MissionControl::Jobs (/jobs). Admin-only.
class AdminController < ActionController::Base
  include ActiveAdminAuthentication

  before_action :authenticate_active_admin_user!
end
