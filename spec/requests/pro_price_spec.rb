# frozen_string_literal: true

require 'rails_helper'

# The Pro price is shown from one constant (User::PRO_PRICES_PLN) everywhere.
RSpec.describe 'Pro price', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  before { stub_const('User::PRO_PRICES_PLN', { monthly: BigDecimal('24.90'), yearly: BigDecimal('249') }) }

  it 'shows the constant on the landing page and in the terms' do
    get root_path
    expect(response.body).to include('24,90 zł', 'lub 249 zł rocznie', 'Plan Pro (24,90 zł/mies. lub 249 zł/rok)')
    get terms_path
    expect(response.body).to include('24,90 PLN brutto', '249 PLN brutto')
  end

  it 'shows the constant on the profile and upgrade page' do
    post session_path, params: { email_address: user.email_address, password: 'password123' }
    get profile_path
    expect(response.body).to include('Przejdź na Pro — 24,90 zł/mies.')
    get upgrade_path
    expect(response.body).to include('24,90 zł', '249 zł', '20,75 zł')
  end
end
