# frozen_string_literal: true

require 'rails_helper'

# Admin → 200 is checked manually: the engine needs Redis and its initializer is skipped in test.
RSpec.describe 'RailsPerformance /rails/performance access', type: :request do
  it 'is not routable for anonymous visitors' do
    get '/rails/performance'
    expect(response).to have_http_status(:not_found)
  end

  it 'is not routable for non-admin users' do
    user = create(:user, password: 'password123', password_confirmation: 'password123')
    post session_path, params: { email_address: user.email_address, password: 'password123' }

    get '/rails/performance'
    expect(response).to have_http_status(:not_found)
  end
end
