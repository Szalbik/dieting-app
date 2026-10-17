# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /users/:id', type: :request do
  include ActiveJob::TestHelper

  let!(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  it 'updates the first name without a password' do
    login
    patch user_path(user), params: { user: { first_name: 'Nowe' } }

    expect(response).to redirect_to(profile_path)
    expect(user.reload.first_name).to eq('Nowe')
  end

  it 'refuses to change the email without the current password' do
    login
    old_email = user.email_address

    patch user_path(user), params: { user: { email_address: 'new@example.com' } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.email_address).to eq(old_email)
  end

  it 'changes the email with the current password, notifies the old address and drops other sessions' do
    login
    old_email = user.email_address
    other_session = user.sessions.create!(user_agent: 'other', ip_address: '10.0.0.1')

    expect do
      perform_enqueued_jobs do
        patch user_path(user), params: { user: { email_address: 'new@example.com' }, current_password: 'password123' }
      end
    end.to change { ActionMailer::Base.deliveries.count }.by(1)

    expect(response).to redirect_to(profile_path)
    expect(user.reload.email_address).to eq('new@example.com')
    expect(ActionMailer::Base.deliveries.last.to).to eq([old_email])
    expect(Session.exists?(other_session.id)).to be(false)
    expect(user.sessions.count).to eq(1)

    get profile_path
    expect(response).to have_http_status(:success)
  end
end
