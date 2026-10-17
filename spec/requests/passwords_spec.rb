# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Password Reset', type: :request do
  include ActiveJob::TestHelper

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
        perform_enqueued_jobs do
          post passwords_path, params: { email_address: user.email_address }
        end
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

    it 'resets the password and revokes every existing session' do
      stolen = user.sessions.create!(user_agent: 'attacker', ip_address: '10.0.0.1')

      patch password_path(user.password_reset_token), params: { password: 'newpass123', password_confirmation: 'newpass123' }

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate('newpass123')).to be_truthy
      expect(Session.exists?(stolen.id)).to be(false)
      expect(user.sessions.count).to eq(0)
    end
  end
end
