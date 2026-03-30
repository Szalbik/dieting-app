# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password Reset', type: :request do
  let!(:user) { FactoryBot.create(:user, password: 'password123', password_confirmation: 'password123') }

  describe 'GET /passwords/new' do
    it 'renders the password reset request form' do
      get new_password_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /passwords' do
    it 'sends reset instructions if user exists' do
      expect do
        post passwords_path, params: { email_address: user.email_address }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(response).to redirect_to(new_session_path)
    end

    it 'redirects even if user does not exist' do
      post passwords_path, params: { email_address: 'notfound@example.com' }
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe 'PATCH /passwords/:token' do
    let(:token) { 'invalidtoken' }

    it 'fails with invalid token' do
      patch password_path(token), params: { password: 'newpass', password_confirmation: 'newpass' }
      expect(response).to redirect_to(new_password_path)
    end

    # To test valid token, you would need to generate a real token for the user
    it 'skips valid token reset (integration test needed)' do
      skip 'Integration test for valid token reset not implemented here.'
    end
  end
end
