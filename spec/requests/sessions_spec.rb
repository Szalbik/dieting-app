# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Sessions', type: :request do
  let!(:user) { FactoryBot.create(:user, password: 'password123', password_confirmation: 'password123') }

  describe 'GET /sessions/new' do
    it 'renders the login form' do
      get new_session_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /sessions' do
    it 'logs in with valid credentials' do
      post session_path, params: { email_address: user.email_address, password: 'password123' }
      expect(response).to redirect_to(root_path)
    end

    it 'does not log in with invalid password' do
      post session_path, params: { email_address: user.email_address, password: 'wrong' }
      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include('Try another email address or password')
    end
  end

  describe 'DELETE /sessions' do
    it 'logs out the user' do
      # Log in first
      post session_path, params: { email_address: user.email_address, password: 'password123' }
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end
  end
end
