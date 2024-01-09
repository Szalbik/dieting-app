# frozen_string_literal: true

class Todoist::ProjectsController < ApplicationController
  def index
    if session[:todoist_token].blank?
      redirect_to profile_path, alert: 'Please authorize Todoist first in your profile'
    else
      @diet_set_ids = params[:diet_set_ids]
      @projects = Todoist::Api.fetch_projects(session[:todoist_token])
    end
  end
end
