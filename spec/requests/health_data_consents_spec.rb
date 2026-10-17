# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health data consent', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  before { post session_path, params: { email_address: user.email_address, password: 'password123' } }

  it 'lets the user grant the consent from the profile' do
    get profile_path
    expect(response.body).to include('Wyrażam zgodę')

    post health_data_consent_path
    expect(response).to redirect_to(profile_path)
    expect(user.reload.consented?(:health_data)).to be(true)
  end

  it 'lets the user withdraw the consent from the profile' do
    user.record_consent!(:health_data)
    get profile_path
    expect(response.body).to include('Wycofaj zgodę')

    delete health_data_consent_path
    expect(response).to redirect_to(profile_path)
    expect(user.reload.consented?(:health_data)).to be(false)
  end
end
