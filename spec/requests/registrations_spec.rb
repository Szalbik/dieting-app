# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Registration', type: :request do
  describe 'GET /registrations/new' do
    it 'renders the registration form' do
      get new_registration_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /registrations' do
    let(:valid_params) do
      {
        user: {
          email_address: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    it 'registers a new user with valid params' do
      expect do
        post registrations_path, params: valid_params
      end.to change(User, :count).by(1)
      expect(response).to redirect_to(root_path)
      follow_redirect!
    end

    it 'does not register with invalid email' do
      invalid_params = valid_params.deep_dup
      invalid_params[:user][:email_address] = 'invalid_email'
      post registrations_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('invalid')
    end

    it 'does not register with password mismatch' do
      invalid_params = valid_params.deep_dup
      invalid_params[:user][:password_confirmation] = 'wrong'
      post registrations_path, params: invalid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('invalid')
    end

    it 'does not register with duplicate email' do
      FactoryBot.create(:user, email_address: valid_params[:user][:email_address])
      post registrations_path, params: valid_params
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('invalid')
    end
  end
end
