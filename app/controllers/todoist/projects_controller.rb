# frozen_string_literal: true

class Todoist::ProjectsController < ApplicationController
  def index
    if todoist_token.blank?
      redirect_to profile_path, alert: 'Please authorize Todoist first in your profile'
    else
      @diet_set_ids = diets_params[:diet_set_ids] || []
      @diet_set_quantities = diets_params[:diet_set_quantities] || {} # diet page sends ids only
      @projects = Todoist::Api.fetch_projects(todoist_token)
    end
  end

  private

  def diets_params
    params.permit(diet_set_quantities: {}, diet_set_ids: [])
  end
end
