# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Shopping carts', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'GET /shopping_cart' do
    it 'redirects when not authenticated' do
      get shopping_cart_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'renders for the logged-in user' do
      login
      get shopping_cart_path
      expect(response).to have_http_status(:success)
    end
  end
end
