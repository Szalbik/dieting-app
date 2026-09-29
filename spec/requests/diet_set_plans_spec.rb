# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DietSetPlans servings', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:diet) { create(:diet, user: user) }
  let(:diet_set) { create(:diet_set, diet: diet) }
  let(:meal) { create(:meal, diet_set: diet_set) }
  let!(:product) { create(:product, meal: meal, diet_set: diet_set) }
  let(:date) { Date.current + 1.day }

  def login(as = user)
    post session_path, params: { email_address: as.email_address, password: 'password123' }
  end

  def plan_for(date, servings: 1, set: diet_set, created_at: 1.day.ago)
    plan = create(:diet_set_plan, diet_set: set, diet: set.diet, date: date, servings: servings, created_at: created_at)
    set.meals.each { |m| create(:meal_plan, diet_set_plan: plan, meal: m, selected_for_cart: true) }
    plan
  end

  describe 'PATCH servings' do
    let!(:plan) { plan_for(date) }

    before { login }

    it 'saves servings and multiplies the cart quantity' do
      patch servings_diet_set_plans_path, params: { date: date.to_s, servings: 3 }

      expect(plan.reload.servings).to eq(3)
      expect(user.shopping_cart.shopping_cart_items.find_by!(product: product).quantity).to eq(3)
      expect(response).to redirect_to(diet_set_plans_path(date: date.to_s))
    end

    it 'clamps to 1..10' do
      patch servings_diet_set_plans_path, params: { date: date.to_s, servings: 99 }
      expect(plan.reload.servings).to eq(10)

      patch servings_diet_set_plans_path, params: { date: date.to_s, servings: 0 }
      expect(plan.reload.servings).to eq(1)
    end

    it 'does not touch another user\'s plan' do
      other = create(:user, password: 'password123', password_confirmation: 'password123')
      other_diet_set = create(:diet_set, diet: create(:diet, user: other))
      other_plan = plan_for(date, servings: 2, set: other_diet_set)
      other_plan.update_columns(created_at: Time.current + 1.hour)

      patch servings_diet_set_plans_path, params: { date: date.to_s, servings: 5 }

      expect(other_plan.reload.servings).to eq(2)
      expect(plan.reload.servings).to eq(5)
    end

    it 'redirects with an alert when the date has no plan' do
      patch servings_diet_set_plans_path, params: { date: (date + 3.days).to_s, servings: 4 }

      expect(response).to redirect_to(diet_set_plans_path(date: (date + 3.days).to_s))
      expect(flash[:alert]).to be_present
    end
  end

  describe 'POST create (reassign)' do
    it 'carries servings over to the new plan' do
      plan_for(date, servings: 2)
      other_set = create(:diet_set, diet: diet)
      create(:meal, diet_set: other_set)
      login

      post diet_set_plans_path, params: { date: date.to_s, diet_set_plan: { diet_set_id: other_set.id } }

      expect(user.diet_set_plans.where(date: date).order(created_at: :desc).first.servings).to eq(2)
    end

    it 'defaults to 1 when the date had no plan' do
      login
      post diet_set_plans_path, params: { date: date.to_s, diet_set_plan: { diet_set_id: diet_set.id } }

      expect(user.diet_set_plans.find_by!(date: date).servings).to eq(1)
    end
  end

  describe 'POST swap' do
    it 'keeps servings on their date' do
      monday = plan_for(date, servings: 2)
      tuesday = plan_for(date + 1.day, servings: 1)
      login

      post swap_diet_set_plans_path, params: { current_date: date.to_s, target_date: (date + 1.day).to_s }

      expect(monday.reload.date).to eq(date + 1.day)
      expect(monday.servings).to eq(1)
      expect(tuesday.reload.date).to eq(date)
      expect(tuesday.servings).to eq(2)
    end
  end
end
