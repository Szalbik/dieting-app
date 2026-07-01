# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DietSets', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'POST /diet_sets' do
    it 'adds a day to a manual diet' do
      diet = create(:diet, user: user, source: 'manual')
      login

      expect do
        post diet_sets_path, params: { diet_set: { diet_id: diet.id } }
      end.to change { diet.diet_sets.count }.by(1)

      expect(response).to redirect_to(diet_set_path(diet.diet_sets.last))
    end

    it 'refuses to add a day to a pdf diet' do
      diet = create(:diet, user: user, source: 'pdf')
      login

      expect do
        post diet_sets_path, params: { diet_set: { diet_id: diet.id } }
      end.not_to(change { diet.diet_sets.count })
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /diet_sets/:id' do
    it 'renders the day editor for a manual diet' do
      diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'manual'))
      login

      get diet_set_path(diet_set)

      expect(response).to have_http_status(:success)
    end

    it 'returns 404 for a pdf diet' do
      diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'pdf'))
      login

      get diet_set_path(diet_set)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /diet_sets/:id' do
    it 'refuses to remove a day from a generated diet' do
      diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'generated'))
      login

      delete diet_set_path(diet_set)

      expect(response).to have_http_status(:not_found)
    end
  end
end
