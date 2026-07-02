# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legal pages', type: :request do
  it 'renders the terms of service without authentication' do
    get terms_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Regulamin serwisu AsystentDiety')
  end

  it 'renders the privacy policy without authentication' do
    get privacy_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Polityka prywatności AsystentDiety')
  end

  it 'renders the cookies policy without authentication' do
    get cookies_policy_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Polityka cookies AsystentDiety')
  end
end
