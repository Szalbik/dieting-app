# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Profile', type: :request do
  let!(:user) { FactoryBot.create(:user, password: 'password123', password_confirmation: 'password123') }

  def login(user)
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'GET /profile' do
    it 'redirects to login if not authenticated' do
      get profile_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'shows the profile page for logged-in user' do
      login(user)
      get profile_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include(user.email_address)
    end
  end

  # Placeholder for edit/update specs
  describe 'PATCH /profile' do
    # it 'updates the profile' do
    #   login(user)
    #   patch user_path(user), params: { user: { first_name: 'NewName', email_address: 'new@example.com' } }
    #   expect(response).to redirect_to(profile_path)
    #   follow_redirect!
    #   expect(response.body).to include('NewName')
    #   expect(response.body).to include('value="new@example.com"')
    #   user.reload
    #   expect(user.first_name).to eq('NewName')
    #   expect(user.email_address).to eq('new@example.com')
    # end
  end
end
