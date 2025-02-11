# frozen_string_literal: true

# HealthController is used to check if the application is up and running.
class HealthController < ApplicationController
  allow_unauthenticated_access

  rescue_from(Exception) { render_down }

  def show
    render_up
  end

  private

  def render_up
    render html: html_status(color: 'green'), status: :ok
  end

  def render_down
    render html: html_status(color: 'red'), status: :service_unavailable
  end

  def html_status(color:)
    %(<html><body style="background-color: #{color}"></body></html>).html_safe
  end
end
