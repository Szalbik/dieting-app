# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legal pages', type: :request do
  it 'renders the terms of service without authentication' do
    get terms_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Regulamin serwisu DietApp')
  end

  it 'renders the privacy policy without authentication' do
    get privacy_path
    expect(response).to have_http_status(:success)
    expect(response.body).to include('Polityka prywatności DietApp')
  end
end
