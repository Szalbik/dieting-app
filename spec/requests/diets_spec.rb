# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Diets', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }
  let(:other_user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  let(:consents) { { pii_confirmed: '1', parse_disclaimer: '1', health_data: '1' } }

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

    it 'asks for confirmation before deleting a diet' do
      login
      create(:diet, user: user, name: 'Keto')
      get diets_path

      confirm = 'data-turbo-confirm="Usunąć dietę „Keto” wraz ze wszystkimi dniami i posiłkami? ' \
                'Tej operacji nie można cofnąć."'
      expect(response.body.scan(confirm).size).to eq(2) # desktop + mobile
      expect(response.body).not_to include('data-confirm=')
    end

    it 'shows the diets list in Polish' do
      login
      create(:diet_set, diet: create(:diet, user: user, name: 'Keto', created_at: Time.zone.local(2026, 3, 5)))
      get diets_path

      expect(response.body).to include('1 zestaw', '05.03.2026', 'Edytuj', 'Nazwa')
      expect(response.body).not_to include('1 zestawów')
      ['>Edit<', '>Delete<', 'Preview pdf', 'Sets number', 'Are you sure', 'March'].each do |english|
        expect(response.body).not_to include(english)
      end
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

    it 'hides the AI wizard and blank diet tabs while only pdf mode is enabled' do
      login
      get new_diet_path
      expect(response.body).not_to include('Kreator AI', 'Zacznij od zera')
    end

    it 'shows every tab when all creation modes are enabled' do
      stub_const('Diet::CREATION_MODES', %w[pdf generated manual])
      login
      get new_diet_path
      expect(response.body).to include('Wgraj PDF', 'Kreator AI', 'Zacznij od zera')
    end
  end

  describe 'POST /diets' do
    it 'enqueues DietBuilderJob when a pdf is attached' do
      login
      pdf = fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf')
      expect do
        post diets_path, params: { diet: { name: 'PDF diet', meals_per_day: 5, pdf: pdf, **consents } }
      end.to have_enqueued_job(DietBuilderJob)

      diet = Diet.find_by(name: 'PDF diet', user: user)
      expect(diet.source).to eq('pdf')
      expect(diet.status).to eq('generating')
    end

    context 'with the upload consents' do
      let(:pdf) { fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf') }

      it 'rejects a pdf without the personal-data statement, without spending quota' do
        login
        expect do
          post diets_path, params: { diet: { name: 'No PII ack', pdf: pdf, parse_disclaimer: '1' } }
        end.not_to have_enqueued_job(DietBuilderJob)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('nie zawiera danych osobowych')
        expect(Diet.find_by(name: 'No PII ack')).to be_nil
        expect(user.reload.ai_free_used_count.to_i).to eq(0)
      end

      it 'rejects a first pdf without the parsing disclaimer' do
        login
        expect do
          post diets_path, params: { diet: { name: 'No disclaimer', pdf: pdf, pii_confirmed: '1' } }
        end.not_to change(Diet, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('automatycznym odczycie')
      end

      it 'records both statements when the pdf is accepted' do
        login
        post diets_path, params: { diet: { name: 'Acked', pdf: pdf, **consents } }

        expect(Diet.find_by(name: 'Acked').pii_confirmed_at).to be_present
        expect(user.reload.consented?(:parse_disclaimer)).to be(true)
      end

      it 'only asks for the personal-data statement once the disclaimer was accepted' do
        user.record_consent(:parse_disclaimer)
        user.record_consent(:health_data)
        user.save!
        login
        get new_diet_path
        expect(response.body).to include('diet[pii_confirmed]')
        expect(response.body).not_to include('diet[parse_disclaimer]', 'diet[health_data]')

        expect do
          post diets_path, params: { diet: { name: 'Second', pdf: pdf, pii_confirmed: '1' } }
        end.to have_enqueued_job(DietBuilderJob)
      end

      it 'shows all checkboxes to a user who never accepted the disclaimer' do
        login
        get new_diet_path
        expect(response.body).to include('diet[pii_confirmed]', 'diet[parse_disclaimer]', 'diet[health_data]')
      end

      it 'rejects a first pdf without the explicit health-data consent' do
        login
        expect do
          post diets_path, params: { diet: { name: 'No health consent', pdf: pdf, **consents.except(:health_data) } }
        end.not_to have_enqueued_job(DietBuilderJob)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('danych dotyczących zdrowia')
        expect(user.reload.consented?(:health_data)).to be(false)
      end

      it 'gates the AI wizard on the health-data consent too, should it be re-enabled' do
        stub_const('Diet::CREATION_MODES', %w[pdf generated])
        login
        expect do
          post diets_path, params: { diet: { name: 'Wizard', kcal_target: 1800, goal: 'redukcja' } }
        end.not_to have_enqueued_job(GenerateDietJob)
        expect(response.body).to include('danych dotyczących zdrowia')
      end

      it 'records the health-data consent with the accepted pdf' do
        login
        post diets_path, params: { diet: { name: 'Health ok', pdf: pdf, **consents } }
        expect(user.reload.consented?(:health_data)).to be(true)
      end
    end

    context 'with a file that is not a real pdf' do
      let(:fake_pdf) do
        file = Tempfile.new(['not-a-pdf', '.pdf'])
        file.write('hello, not a pdf')
        file.rewind
        Rack::Test::UploadedFile.new(file.path, 'application/pdf')
      end

      it 'rejects it by magic bytes before enqueueing or spending quota' do
        login
        expect do
          post diets_path, params: { diet: { name: 'Fake', pdf: fake_pdf, **consents } }
        end.not_to have_enqueued_job(DietBuilderJob)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('Plik musi być PDF-em o rozmiarze do 10 MB.')
        expect(Diet.find_by(name: 'Fake')).to be_nil
        expect(user.reload.ai_free_used_count.to_i).to eq(0)
      end
    end

    it 'rejects a pdf above the byte cap' do
      stub_const('ApplicationController::MAX_PDF_BYTES', 1000)
      login
      pdf = fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf')

      expect do
        post diets_path, params: { diet: { name: 'Huge', pdf: pdf, **consents } }
      end.not_to have_enqueued_job(DietBuilderJob)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Diet.find_by(name: 'Huge')).to be_nil
    end

    it 'rejects a submit without a pdf when only pdf mode is enabled' do
      login
      expect do
        post diets_path, params: { diet: { name: 'No file diet', meals_per_day: 5 } }
      end.not_to change(Diet, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Wybierz plik PDF z dietą.')
    end

    it 'rejects the AI wizard when it is disabled without consuming quota' do
      login
      expect do
        post diets_path, params: { diet: { name: 'Blocked AI diet', kcal_target: 1800 } }
      end.not_to have_enqueued_job(GenerateDietJob)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Diet.find_by(name: 'Blocked AI diet')).to be_nil
      expect(user.reload.ai_free_used_count.to_i).to eq(0)
    end

    context 'with all creation modes enabled' do
      before do
        stub_const('Diet::CREATION_MODES', %w[pdf generated manual])
        user.record_consent!(:health_data)
      end

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
      before do
        stub_const('Diet::CREATION_MODES', %w[pdf generated manual])
        user.record_consent!(:health_data)
      end

      it 'allows a free user 1 pdf/generated diet in total, then blocks the next' do
        login
        pdf = fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf')
        post diets_path, params: { diet: { name: 'First AI diet', meals_per_day: 5, pdf: pdf, **consents } }
        expect(Diet.where(user: user).count).to eq(1)

        expect do
          post diets_path, params: { diet: { name: 'Second AI diet', kcal_target: 1800 } }
        end.not_to have_enqueued_job(GenerateDietJob)

        expect(response).to redirect_to(new_diet_path)
        expect(flash[:alert]).to include('Przejdź na Pro')
        expect(Diet.find_by(name: 'Second AI diet')).to be_nil
      end

      it 'always allows manual diets regardless of quota' do
        login
        user.update!(ai_free_used_count: 3)
        post diets_path, params: { diet: { name: 'Manual diet', meals_per_day: 5 } }
        expect(response).to redirect_to(diets_path)
        expect(Diet.find_by(name: 'Manual diet')).to be_present
      end

      it 'lets a Pro user past the free limit, up to 3 per month' do
        login
        user.update!(subscription: :active, ai_free_used_count: 3, ai_quota_used_count: 2,
                     ai_quota_period_started_at: Time.current.beginning_of_month)
        post diets_path, params: { diet: { name: 'Pro AI diet 3', kcal_target: 1800 } }
        expect(Diet.find_by(name: 'Pro AI diet 3')).to be_present

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

  describe 'PATCH /diets/:id' do
    it 'ignores a pdf sent with an update' do
      diet = create(:diet, user: user, name: 'Old name')
      pdf = fixture_file_upload(Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'), 'application/pdf')
      login

      patch diet_path(diet), params: { diet: { name: 'New name', pdf: pdf } }

      expect(diet.reload.name).to eq('New name')
      expect(diet.pdf).not_to be_attached
    end
  end

  describe 'GET /diets/:id/pdf' do
    let!(:diet) { create(:diet, :with_pdf, user: user) }

    it 'redirects when not authenticated' do
      get pdf_diet_path(diet)
      expect(response).to redirect_to(new_session_path)
    end

    it 'serves the owner their pdf' do
      login
      get pdf_diet_path(diet)
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/pdf')
      expect(response.body).to start_with('%PDF')
    end

    it 'returns 404 for another user diet' do
      login(other_user)
      get pdf_diet_path(diet)
      expect(response).to have_http_status(:not_found)
    end

    it 'is what the index links to, instead of a permanent Active Storage url' do
      login
      get diets_path
      expect(response.body).to include(pdf_diet_path(diet))
      expect(response.body).not_to include('rails/active_storage')
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

    it 'shows the parsing state instead of an empty day list for a pdf diet still loading' do
      loading = create(:diet, :with_pdf, user: user, source: 'pdf', status: 'generating')
      login
      get diet_path(loading)
      expect(response.body).to include('Wczytujemy Twój PDF')
    end

    it 'shows the error and a retry for a pdf diet whose parse failed' do
      failed = create(:diet, :with_pdf, user: user, source: 'pdf', status: 'failed',
                                        generation_error: 'OpenAI API error: boom')
      login
      get diet_path(failed)
      expect(response.body).to include('Nie udało się wczytać PDF', 'Przeparsuj')
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

    it 'answers a Turbo submission with a 303 redirect so the index morphs instead of a stream removing the row' do
      diet.update!(active: true)
      login

      patch toggle_active_diet_path(diet), headers: { 'Accept' => 'text/vnd.turbo-stream.html, text/html' }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(diets_path)
      expect(response.media_type).not_to eq(Mime[:turbo_stream].to_s)
      expect(diet.reload.active).to be false
    end
  end

  describe 'GET /diets toggle markup' do
    it 'renders every diet with a full row and a mobile card in the matching tab' do
      active = create(:diet, user: user, active: true)
      inactive = create(:diet, user: user, active: false)
      login

      get diets_path

      html = Nokogiri::HTML(response.body)
      [active, inactive].each do |d|
        expect(html.css("#diet_row_#{d.id} > td").size).to eq(5)
        expect(html.at_css("#diet_row_#{d.id} #diet_toggle_#{d.id} form")).to be_present
      end
      expect(html.at_css("#diet_card_mobile_#{active.id}")['data-tab-value']).to eq('aktywne')
      expect(html.at_css("#diet_card_mobile_#{inactive.id}")['data-tab-value']).to eq('zakonczone')
    end
  end

  describe 'POST /diets/:id/reparse' do
    let(:diet) { create(:diet, :with_pdf, user: user) }

    before { user.record_consent!(:health_data) }

    it 'refuses to reparse after the health-data consent was withdrawn' do
      user.update!(consents: {})
      login
      expect do
        post reparse_diet_path(diet), params: { pii_confirmed: '1' }
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(profile_path)
      expect(flash[:alert]).to include('danych dotyczących zdrowia')
    end

    it 'enqueues DietBuilderJob when PDF is attached' do
      login
      expect do
        post reparse_diet_path(diet), params: { pii_confirmed: '1' }
      end.to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
      expect(diet.reload.status).to eq('generating')
    end

    it 'lets the user reparse a diet stuck in generating by a dead worker' do
      diet.update!(status: 'generating')
      diet.update_column(:updated_at, 2.hours.ago) # rubocop:disable Rails/SkipsModelValidations
      login
      expect do
        post reparse_diet_path(diet), params: { pii_confirmed: '1' }
      end.to have_enqueued_job(DietBuilderJob)
    end

    it 'refuses to reparse while a parse is already running' do
      diet.update!(status: 'generating')
      login
      expect do
        post reparse_diet_path(diet), params: { pii_confirmed: '1' }
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(user.reload.ai_free_used_count.to_i).to eq(0)
      follow_redirect!
      expect(response.body).to include('właśnie wczytywana')
    end

    it 'redirects with alert when PDF is missing' do
      bare = create(:diet, user: user)
      login
      expect do
        post reparse_diet_path(bare), params: { pii_confirmed: '1' }
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
      follow_redirect!
      expect(response.body).to include('Brak załączonego PDF')
    end

    it 'refuses to reparse without the personal-data statement' do
      login
      expect do
        post reparse_diet_path(diet)
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
      expect(flash[:alert]).to include('danych osobowych')
      expect(user.reload.ai_free_used_count.to_i).to eq(0)
    end

    it 'records the personal-data statement on a confirmed reparse' do
      login
      post reparse_diet_path(diet), params: { pii_confirmed: '1' }
      expect(diet.reload.pii_confirmed_at).to be_present
    end

    it 'blocks reparse when the free quota is already spent' do
      user.update!(ai_free_used_count: 3)
      login
      expect do
        post reparse_diet_path(diet), params: { pii_confirmed: '1' }
      end.not_to have_enqueued_job(DietBuilderJob)
      expect(response).to redirect_to(diets_path)
    end
  end
end
