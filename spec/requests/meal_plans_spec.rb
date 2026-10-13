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

RSpec.describe 'MealPlans toggle_eaten from the offline outbox', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:diet_set) { create(:diet_set, diet: create(:diet, user: user)) }
  let(:plan) { create(:diet_set_plan, diet_set: diet_set, date: Date.current) }
  let!(:meal_plan) { create(:meal_plan, diet_set_plan: plan, meal: create(:meal, diet_set: diet_set)) }
  let(:outbox_headers) { { 'Accept' => 'text/vnd.turbo-stream.html, text/html' } }

  before { post session_path, params: { email_address: user.email_address, password: 'password123' } }

  it 'sets eaten and stays eaten when replayed' do
    2.times { patch toggle_eaten_meal_plan_path(meal_plan), params: { eaten: 'true' }, headers: outbox_headers }
    expect(meal_plan.reload).to be_eaten
  end

  it 'unsets eaten with an explicit false' do
    meal_plan.update!(eaten: true)
    patch toggle_eaten_meal_plan_path(meal_plan), params: { eaten: 'false' }, headers: outbox_headers
    expect(meal_plan.reload).not_to be_eaten
  end

  it 'answers 204 instead of redirecting' do
    patch toggle_eaten_meal_plan_path(meal_plan), params: { eaten: 'true' }, headers: outbox_headers
    expect(response).to have_http_status(:no_content)
  end
end
