# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Recipes', type: :request do
  let(:admin) { create(:user, admin: true, password: 'password123', password_confirmation: 'password123') }

  describe 'GET /recipes' do
    it 'asks for confirmation before deleting a recipe' do
      create(:recipe, user: admin)
      post session_path, params: { email_address: admin.email_address, password: 'password123' }

      get recipes_path

      expect(response.body).to include('data-turbo-confirm="Usunąć przepis?"')
      expect(response.body).not_to include('data-confirm=')
    end
  end
end
