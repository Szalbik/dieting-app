# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Todoist OAuth callback', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  before { post session_path, params: { email_address: user.email_address, password: 'password123' } }

  it 'rejects a callback when the flow was never started (no state on either side)' do
    allow(HTTParty).to receive(:post)

    get todoist_receive_code_path(code: 'attacker-code')

    expect(response).to have_http_status(:bad_request)
    expect(HTTParty).not_to have_received(:post)
  end

  it 'rejects a mismatched state' do
    allow(HTTParty).to receive(:post)
    allow(Rails.application.credentials).to receive(:todoist).and_return({ client_id: 'id', client_secret: 'secret' })
    get todoist_authorize_path

    get todoist_receive_code_path(code: 'attacker-code', state: 'wrong')

    expect(response).to have_http_status(:bad_request)
    expect(HTTParty).not_to have_received(:post)
  end
end
