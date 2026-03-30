# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Products', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'GET /products' do
    it 'redirects to login when not authenticated' do
      get products_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'returns success for logged-in user without filter params' do
      login
      get products_path
      expect(response).to have_http_status(:success)
    end
  end
end
