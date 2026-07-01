# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Meals', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  describe 'POST /meals' do
    it 'adds a manually written meal to a manual diet' do
      diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'manual'))
      login

      expect do
        post meals_path, params: { meal: { diet_set_id: diet_set.id, name: 'Owsianka', kcal: 300 } }
      end.to change { diet_set.reload.meals.count }.by(1)

      expect(response).to redirect_to(diet_set_path(diet_set))
    end

    it 'refuses to add a meal to a pdf diet' do
      diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'pdf'))
      login

      expect do
        post meals_path, params: { meal: { diet_set_id: diet_set.id, name: 'Owsianka', kcal: 300 } }
      end.not_to(change { diet_set.reload.meals.count })
      expect(response).to have_http_status(:not_found)
    end

    it 'copies a meal from a pdf diet into a manual diet day' do
      source_meal = create(:meal, diet_set: create(:diet_set, diet: create(:diet, user: user, source: 'pdf')))
      manual_diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'manual'))
      login

      expect do
        post meals_path, params: { meal: { diet_set_id: manual_diet_set.id, source_meal_id: source_meal.id } }
      end.to change { manual_diet_set.reload.meals.count }.by(1)

      expect(response).to redirect_to(diet_set_path(manual_diet_set))
    end

    it 'refuses to copy a meal into a pdf diet day' do
      source_meal = create(:meal)
      pdf_diet_set = create(:diet_set, diet: create(:diet, user: user, source: 'pdf'))
      login

      post meals_path, params: { meal: { diet_set_id: pdf_diet_set.id, source_meal_id: source_meal.id } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /meals/:id' do
    it 'removes a meal from a manual diet' do
      meal = create(:meal, diet_set: create(:diet_set, diet: create(:diet, user: user, source: 'manual')))
      login

      delete meal_path(meal)

      expect(response).to redirect_to(diet_set_path(meal.diet_set))
      expect(Meal.exists?(meal.id)).to be false
    end

    it 'refuses to remove a meal from a generated diet' do
      meal = create(:meal, diet_set: create(:diet_set, diet: create(:diet, user: user, source: 'generated')))
      login

      delete meal_path(meal)

      expect(response).to have_http_status(:not_found)
      expect(Meal.exists?(meal.id)).to be true
    end
  end
end
