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
    it 'enqueues DietBuilderJob when a pdf is attached' do
      login
      pdf = fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf')
      expect do
        post diets_path, params: { diet: { name: 'PDF diet', meals_per_day: 5, pdf: pdf } }
      end.to have_enqueued_job(DietBuilderJob)

      expect(Diet.find_by(name: 'PDF diet', user: user).source).to eq('pdf')
    end

    it 'rejects a submit without a pdf when only pdf mode is enabled' do
      login
      expect do
        post diets_path, params: { diet: { name: 'No file diet', meals_per_day: 5 } }
      end.not_to change(Diet, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects the AI wizard when it is disabled without consuming quota' do
      login
      expect do
        post diets_path, params: { diet: { name: 'Blocked AI diet', kcal_target: 1800 } }
      end.not_to have_enqueued_job(GenerateDietJob)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Diet.find_by(name: 'Blocked AI diet')).to be_nil
      expect(user.reload.ai_quota_used_count.to_i).to eq(0)
    end

    context 'with all creation modes enabled' do
      before { stub_const('Diet::CREATION_MODES', %w[pdf generated manual]) }

      it 'creates a manual diet without enqueuing a job when no pdf or kcal_target is given' do
        login
        expect do
          post diets_path, params: { diet: { name: 'Fresh diet', meals_per_day: 5 } }
        end.not_to have_enqueued_job(DietBuilderJob)

        expect(response).to redirect_to(diets_path)
        diet = Diet.find_by(name: 'Fresh diet', user: user)
        expect(diet).to be_present
        expect(diet.source).to eq('manual')
        expect(diet.active).to be true
      end

      it 'enqueues GenerateDietJob when a kcal_target is given' do
        login
        expect do
          post diets_path, params: { diet: { name: 'AI diet', kcal_target: 1800 } }
        end.to have_enqueued_job(GenerateDietJob)

        diet = Diet.find_by(name: 'AI diet', user: user)
        expect(diet.source).to eq('generated')
        expect(diet.meals_per_day).to eq(3)
      end

      it 'derives macro_split from the chosen goal instead of raw percentages' do
        login
        post diets_path, params: { diet: { name: 'Bulk diet', kcal_target: 2800, goal: 'masa' } }

        diet = Diet.find_by(name: 'Bulk diet', user: user)
        expect(diet.generation_prefs['goal']).to eq('masa')
        expected_split = Diet::GOAL_MACROS.fetch('masa').slice('protein_pct', 'fat_pct', 'carbs_pct')
        expect(diet.generation_prefs['macro_split']).to eq(expected_split)
      end

      it 'falls back to the default goal when an unknown goal is submitted' do
        login
        post diets_path, params: { diet: { name: 'Weird goal diet', kcal_target: 1800, goal: 'nonsense' } }

        diet = Diet.find_by(name: 'Weird goal diet', user: user)
        expect(diet.generation_prefs['goal']).to eq('zwykla')
      end
    end
  end

  describe 'POST /diets free-plan AI quota' do
    context 'with all creation modes enabled' do
      before { stub_const('Diet::CREATION_MODES', %w[pdf generated manual]) }

      it 'blocks a second pdf/generated diet in the same month for a free user' do
        login
        pdf = fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf')
        post diets_path, params: { diet: { name: 'First AI diet', meals_per_day: 5, pdf: pdf } }

        expect do
          post diets_path, params: { diet: { name: 'Second AI diet', kcal_target: 1800 } }
        end.not_to have_enqueued_job(GenerateDietJob)

        expect(response).to redirect_to(new_diet_path)
        expect(Diet.find_by(name: 'Second AI diet')).to be_nil
      end

      it 'always allows manual diets regardless of quota' do
        login
        user.update!(ai_quota_used_count: 1, ai_quota_period_started_at: Time.current.beginning_of_month)
        post diets_path, params: { diet: { name: 'Manual diet', meals_per_day: 5 } }
        expect(response).to redirect_to(diets_path)
        expect(Diet.find_by(name: 'Manual diet')).to be_present
      end

      it 'allows a Pro user up to 3 pdf/generated diets per month, then blocks the 4th' do
        login
        user.update!(subscription: :active)
        3.times { |i| post diets_path, params: { diet: { name: "Pro AI diet #{i}", kcal_target: 1800 } } }
        expect(Diet.where(user: user).count).to eq(3)

        expect do
          post diets_path, params: { diet: { name: 'Pro AI diet 4', kcal_target: 1800 } }
        end.not_to have_enqueued_job(GenerateDietJob)
        expect(Diet.find_by(name: 'Pro AI diet 4')).to be_nil
      end

      it 'allows unlimited pdf/generated diets for a lifetime user' do
        login
        user.update!(subscription: :lifetime)
        4.times { |i| post diets_path, params: { diet: { name: "Lifetime AI diet #{i}", kcal_target: 1800 } } }
        expect(Diet.where(user: user).count).to eq(4)
      end
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

    it 'blocks reparse when the free quota is already spent' do
      user.update!(ai_quota_used_count: 1, ai_quota_period_started_at: Time.current.beginning_of_month)
      login
      expect do
        post reparse_diet_path(diet)
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
    end
  end
end
