# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Health', type: :request do
  describe 'GET /show' do
    it 'returns http success' do
      get '/up'
      expect(response).to have_http_status(:success)
    end
  end
end
