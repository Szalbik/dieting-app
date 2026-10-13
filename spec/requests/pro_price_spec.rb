# frozen_string_literal: true

require 'rails_helper'

# The Pro price is shown from one constant everywhere.
RSpec.describe 'Pro price', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  before { stub_const('User::PRO_PRICE_PLN', 19) }

  it 'shows the constant on the landing page and in the terms' do
    get root_path
    expect(response.body).to include('19 zł', 'Plan Pro (19 zł/mies.)')
    get terms_path
    expect(response.body).to include('19 PLN brutto')
  end

  it 'shows the constant on the profile and upgrade page' do
    post session_path, params: { email_address: user.email_address, password: 'password123' }
    get profile_path
    expect(response.body).to include('Przejdź na Pro — 19 zł/mies.')
    get upgrade_path
    expect(response.body).to include('19 zł')
  end
end
