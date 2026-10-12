# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MealPlans toggle_eaten', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:diet_set) { create(:diet_set, diet: create(:diet, user: user)) }
  let(:date) { Date.current + 2.days }
  let(:plan) { create(:diet_set_plan, diet_set: diet_set, date: date) }
  let!(:meal_plan) { create(:meal_plan, diet_set_plan: plan, meal: create(:meal, diet_set: diet_set)) }

  before { post session_path, params: { email_address: user.email_address, password: 'password123' } }

  before { patch toggle_eaten_meal_plan_path(meal_plan) }

  it('marks the meal eaten') { expect(meal_plan.reload).to be_eaten }
  it("returns to the meal's day") { expect(response).to redirect_to(diet_set_plans_path(date: date)) }
  it('confirms with a notice') { expect(flash[:notice]).to include('zjedzone') }
end
