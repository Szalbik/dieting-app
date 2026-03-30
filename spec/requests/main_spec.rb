# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Main', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login(u)
    post session_path, params: { email_address: u.email_address, password: 'password123' }
  end

  describe 'GET /' do
    it 'renders for a guest' do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it 'redirects to diet set plans when authenticated' do
      login(user)
      get root_path
      expect(response).to redirect_to(diet_set_plans_path)
    end
  end

  describe 'GET /style-guide' do
    it 'is reachable without authentication' do
      get style_guide_path
      expect(response).to have_http_status(:success)
    end
  end
end
