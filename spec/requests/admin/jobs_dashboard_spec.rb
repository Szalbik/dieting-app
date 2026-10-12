# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MissionControl /jobs access', type: :request do
  def login(user)
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  it 'redirects anonymous visitors to sign in' do
    get '/jobs'
    expect(response).to redirect_to('/session/new')
  end

  it 'redirects non-admin users' do
    login(create(:user, password: 'password123', password_confirmation: 'password123'))
    get '/jobs'
    expect(response).to redirect_to('/')
  end

  it 'lets admins in' do
    login(create(:user, admin: true, password: 'password123', password_confirmation: 'password123'))
    get '/jobs'
    expect(response).to have_http_status(:ok)
  end
end
