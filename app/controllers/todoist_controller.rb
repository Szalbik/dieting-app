# frozen_string_literal: true

class TodoistController < ApplicationController
  def create
    if session[:todoist_token].blank?
      redirect_to profile_path, alert: 'Please authorize Todoist first in your profile'
    else
      SendToTodoistJob.perform_later(
        params[:diet][:project_id],
        params[:diet][:diet_set_ids],
        diet_set_quantities_params[:diet_set_quantities],
        session[:todoist_token],
        Current.user.id
      )
      redirect_to diets_path, notice: 'Products sent to Todoist'
    end
  end

  def authorize
    session[:state] ||= SecureRandom.hex(10)
    redirect_to("https://todoist.com/oauth/authorize?client_id=#{client_id}&scope=data:read_write&state=#{session[:state]}",
                allow_other_host: true)
  end

  def receive_code
    code = auth_code_params[:code]
    state = auth_code_params[:state]

    return render plain: 'Invalid state', status: :bad_request if state != session[:state]

    response = HTTParty.post('https://todoist.com/oauth/access_token',
                             body: {
                               client_id: client_id,
                               client_secret: client_secret,
                               code: code,
                             })

    return render plain: 'Invalid code', status: :bad_request if response.code != 200

    token = response.parsed_response['access_token']
    # add token to session and expire after 30 minutes
    session[:todoist_token] = { token: token, expires_at: 30.minutes.from_now }

    redirect_to profile_path
  end

  private

  def client_id
    Rails.application.credentials.todoist[:client_id]
  end

  def client_secret
    Rails.application.credentials.todoist[:client_secret]
  end

  def auth_code_params
    params.permit(:code, :state)
  end

  def diet_params
    params.require(:diet).permit(:id, :project_id)
  end

  def diet_set_quantities_params
    params.permit(diet_set_quantities: {})
  end

  def search_params
    params.require(:diet).permit(diet_set_ids: [])
  end
end
