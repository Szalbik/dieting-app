# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Product substitutions', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  def login
    post session_path, params: { email_address: user.email_address, password: 'password123' }
  end

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  describe 'GET /product_substitutions' do
    it 'redirects when not authenticated' do
      get product_substitutions_path
      expect(response).to redirect_to(new_session_path)
    end

    it 'renders the list when logged in' do
      login
      create(:product_substitution, user: user, source_product: 'tunczyk', replacement_product: 'losos')
      get product_substitutions_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /product_substitutions' do
    it 'creates a substitution and enqueues sync jobs' do
      login
      expect do
        post product_substitutions_path, params: {
          product_substitution: { source_product: '  jajka  ', replacement_product: '  tofu  ' },
        }
      end.to change { user.product_substitutions.count }.by(1)
        .and have_enqueued_job(SyncCanonicalProductsJob)
        .and have_enqueued_job(MatchSubstitutionsToProductsJob)

      expect(response).to redirect_to(product_substitutions_path)
    end
  end

  describe 'DELETE /product_substitutions/:id' do
    it 'removes the substitution and enqueues sync jobs' do
      login
      sub = create(:product_substitution, user: user)

      expect do
        delete product_substitution_path(sub)
      end.to change { user.product_substitutions.count }.by(-1)
        .and have_enqueued_job(SyncCanonicalProductsJob)
        .and have_enqueued_job(MatchSubstitutionsToProductsJob)

      expect(response).to redirect_to(product_substitutions_path)
    end
  end

  describe 'POST /product_substitutions/import_pdf' do
    it 'imports rows returned by the parser service' do
      login
      parser = instance_double(Chat::ProductSubstitutionParserService, call: [
        { 'source' => 'mleko', 'replacements' => ['napój owsiany'] },
      ])
      allow(Chat::ProductSubstitutionParserService).to receive(:new).and_return(parser)

      pdf = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/diet_for_one_week.pdf'),
        'application/pdf'
      )

      expect do
        post import_pdf_product_substitutions_path, params: { pdf: pdf }
      end.to change { user.product_substitutions.count }.by(1)

      expect(response).to redirect_to(product_substitutions_path)
    end
  end

  describe 'POST /product_substitutions/rematch' do
    it 'enqueues matching jobs' do
      login
      expect do
        post rematch_product_substitutions_path
      end.to have_enqueued_job(SyncCanonicalProductsJob)
        .and have_enqueued_job(MatchSubstitutionsToProductsJob)
      expect(response).to redirect_to(product_substitutions_path)
    end
  end

  describe 'POST /product_substitutions/expand_ai' do
    it 'enqueues ExpandSubstitutionsWithAiJob' do
      login
      expect do
        post expand_ai_product_substitutions_path
      end.to have_enqueued_job(ExpandSubstitutionsWithAiJob)
      expect(response).to redirect_to(product_substitutions_path)
    end
  end
end
