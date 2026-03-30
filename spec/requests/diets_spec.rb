# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Diets', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:other_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login(u = user)
    post session_path, params: { email_address: u.email_address, password: 'password123' }
  end

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  describe 'GET /diets' do
    it 'redirects when not authenticated' do
      get diets_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'lists diets for the current user' do
      login
      create(:diet, user: user, name: 'My diet plan')
      get diets_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('My diet plan')
    end
  end

  describe 'GET /diets/new' do
    it 'redirects when not authenticated' do
      get new_diet_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'renders the new diet form when logged in' do
      login
      get new_diet_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /diets' do
    it 'enqueues DietBuilderJob and redirects on success' do
      login
      expect do
        post diets_path, params: { diet: { name: 'Fresh diet', meals_per_day: 5 } }
      end.to have_enqueued_job(DietBuilderJob)

      expect(response).to redirect_to(diets_path)
      expect(Diet.find_by(name: 'Fresh diet', user: user)).to be_present
    end
  end

  describe 'GET /diets/:id' do
    let(:diet) { create(:diet, user: user, name: 'Owned diet') }

    it 'returns 404 for another user diet' do
      other_diet = create(:diet, user: other_user, name: 'Secret diet')
      login
      get diet_path(other_diet)
      expect(response).to have_http_status(:not_found)
    end

    it 'shows the diet when it belongs to the user' do
      login
      get diet_path(diet)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Lista produktów')
    end
  end

  describe 'PATCH /diets/:id/toggle_active' do
    let(:diet) { create(:diet, user: user, active: false) }

    it 'toggles active flag' do
      login
      patch toggle_active_diet_path(diet)
      expect(response).to redirect_to(diets_path)
      expect(diet.reload.active).to be true
    end
  end

  describe 'POST /diets/:id/reparse' do
    let(:diet) { create(:diet, :with_pdf, user: user) }

    it 'enqueues DietBuilderJob when PDF is attached' do
      login
      expect do
        post reparse_diet_path(diet)
      end.to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
    end

    it 'redirects with alert when PDF is missing' do
      bare = create(:diet, user: user)
      login
      expect do
        post reparse_diet_path(bare)
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
      follow_redirect!
      expect(response.body).to include('Brak załączonego PDF')
    end
  end
end
