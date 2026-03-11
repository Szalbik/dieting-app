# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietSetPlansController, type: :controller do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:diet) { create(:diet, user: user) }
  let(:diet_set) { create(:diet_set, diet: diet) }
  let(:meal) { create(:meal, diet_set: diet_set) }
  let(:diet_set_plan) { create(:diet_set_plan, diet_set: diet_set, diet: diet, date: Date.current) }
  let(:meal_plan) { create(:meal_plan, diet_set_plan: diet_set_plan, meal: meal) }
  let!(:product) { create(:product, meal: meal, diet_set: diet_set, name: 'Tunczyk') }

  before do
    allow(controller).to receive(:require_authentication).and_return(true)
    allow(controller).to receive(:resume_session).and_return(true)
    allow(Current).to receive(:session).and_return(double(user: user))
  end

  describe 'POST #replace_product' do
    it 'replaces product name permanently for meal' do
      allow(Current).to receive(:user).and_return(user)

      post :replace_product, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        replacement_name: 'Losos',
        date: Date.current
      }

      expect(response).to redirect_to(diet_set_plans_path(date: Date.current.to_s))
      expect(product.reload.name).to eq('Losos')
    end

    it 'does not allow replacing product in another user meal' do
      allow(Current).to receive(:user).and_return(other_user)

      post :replace_product, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        replacement_name: 'Losos',
        date: Date.current
      }

      expect(response).to redirect_to(diet_set_plans_path(date: Date.current.to_s))
      expect(product.reload.name).to eq('Tunczyk')
    end
  end

  describe 'POST #cycle_product_replacement' do
    before do
      create(:product_substitution, user: user, source_product: 'Tunczyk (100g)', replacement_product: 'Losos 140g')
      create(:product_substitution, user: user, source_product: 'Tunczyk (100g)', replacement_product: 'Makrela 120g')
      product.ingredient_measures.create!(amount: 100.0, unit: 'g')
    end

    it 'cycles product to next replacement candidate' do
      allow(Current).to receive(:user).and_return(user)

      post :cycle_product_replacement, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        date: Date.current
      }

      expect(response).to redirect_to(diet_set_plans_path(date: Date.current.to_s))
      product.reload
      expect(%w[Losos Makrela]).to include(product.name)
      expect(product.ingredient_measures.first.amount).to be > 100.0
    end

    it 'returns turbo stream response for turbo_stream format' do
      allow(Current).to receive(:user).and_return(user)

      post :cycle_product_replacement, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        date: Date.current,
        format: :turbo_stream
      }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    end

    it 'returns to base product after cycling through all replacements' do
      allow(Current).to receive(:user).and_return(user)

      3.times do
        post :cycle_product_replacement, params: {
          meal_plan_id: meal_plan.id,
          product_id: product.id,
          date: Date.current
        }
        expect(response).to redirect_to(diet_set_plans_path(date: Date.current.to_s))
      end

      product.reload
      expect(product.name).to eq('Tunczyk')
      expect(product.base_product_name).to eq('Tunczyk')
      expect(product.ingredient_measures.first.amount).to be_within(0.01).of(100.0)
    end

    it 'tracks canonical base and current product during cycling' do
      allow(Current).to receive(:user).and_return(user)

      post :cycle_product_replacement, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        date: Date.current
      }

      product.reload
      expect(product.base_canonical_product).to be_present
      expect(product.canonical_product).to be_present
      expect(product.base_canonical_product.name).to eq('Tunczyk')
      expect(%w[Losos Makrela]).to include(product.canonical_product.name)
    end

    it 'does not allow replacing product in another user meal' do
      allow(Current).to receive(:user).and_return(other_user)

      post :cycle_product_replacement, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        date: Date.current
      }

      expect(response).to redirect_to(diet_set_plans_path(date: Date.current.to_s))
      expect(product.reload.name).to eq('Tunczyk')
    end

    it 'uses AI product match mapping when diet product name differs from substitution source' do
      allow(Current).to receive(:user).and_return(user)
      product.update!(name: 'Jogurt naturalny 2% tluszczu', base_product_name: nil, base_canonical_product: nil)

      create(:product_substitution, user: user, source_product: 'Jogurt naturalny', replacement_product: 'Skyr naturalny')
      create(
        :substitution_product_match,
        user: user,
        source_product: 'Jogurt naturalny',
        matched_product_name: 'Jogurt naturalny 2% tluszczu'
      )

      post :cycle_product_replacement, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        date: Date.current
      }

      product.reload
      expect(product.base_product_name).to eq('Jogurt naturalny')
      expect(product.name).to eq('Skyr naturalny')
    end

    it 'prefers explicit local base name when that base has substitutions' do
      allow(Current).to receive(:user).and_return(user)
      product.update!(name: 'płatków owsianych', base_product_name: 'płatków owsianych')

      create(:product_substitution, user: user, source_product: 'płatków owsianych', replacement_product: 'płatków kukurydzianych')

      post :cycle_product_replacement, params: {
        meal_plan_id: meal_plan.id,
        product_id: product.id,
        date: Date.current
      }

      product.reload
      expect(product.base_product_name).to eq('płatków owsianych')
      expect(product.name).to eq('płatków kukurydzianych')
    end
  end
end
