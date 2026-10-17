# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Todoist OAuth callback', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user, admin: true, password: 'password123', password_confirmation: 'password123') }

  before { post session_path, params: { email_address: user.email_address, password: 'password123' } }

  it 'rejects a callback when the flow was never started (no state on either side)' do
    allow(HTTParty).to receive(:post)

    get todoist_receive_code_path(code: 'attacker-code')

    expect(response).to have_http_status(:bad_request)
    expect(HTTParty).not_to have_received(:post)
  end

  it 'rejects a mismatched state' do
    allow(HTTParty).to receive(:post)
    allow(Rails.application.credentials).to receive(:todoist).and_return({ client_id: 'id', client_secret: 'secret' })
    get todoist_authorize_path

    get todoist_receive_code_path(code: 'attacker-code', state: 'wrong')

    expect(response).to have_http_status(:bad_request)
    expect(HTTParty).not_to have_received(:post)
  end

  context 'with a valid state' do
    include ActiveSupport::Testing::TimeHelpers

    let(:token_response) do
      instance_double(HTTParty::Response, code: 200, parsed_response: { 'access_token' => 'raw-oauth-secret-9f8e7' })
    end

    before do
      allow(Rails.application.credentials).to receive(:todoist).and_return({ client_id: 'id', client_secret: 'secret' })
      allow(HTTParty).to receive(:post).and_return(token_response)
      allow(Todoist::Api).to receive(:fetch_projects)
        .and_return([{ 'id' => '42', 'name' => 'Zakupy', 'is_shared' => false }])
    end

    def authorize_todoist
      get todoist_authorize_path
      state = Rack::Utils.parse_query(URI(response.location).query)['state']
      get todoist_receive_code_path(code: 'good-code', state: state)
      state
    end

    it 'exchanges the code and stores the token' do
      authorize_todoist

      expect(response).to redirect_to(profile_path)
      expect(HTTParty).to have_received(:post).once
    end

    it 'rejects replaying the same state' do
      state = authorize_todoist

      get todoist_receive_code_path(code: 'good-code', state: state)

      expect(response).to have_http_status(:bad_request)
      expect(HTTParty).to have_received(:post).once
    end

    it 'renders the project picker from the diet page (ids only, no quantities)' do
      authorize_todoist

      get todoist_projects_path(diet_set_ids: ['1'])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Zakupy')
    end

    it 'enqueues the shopping list job without the raw OAuth token in its arguments' do
      authorize_todoist

      post todoist_create_path, params: { diet: { project_id: '42', diet_set_ids: ['1'] } }

      expect(enqueued_jobs.last['job_class']).to eq('SendToTodoistJob')
      expect(enqueued_jobs.last['arguments'].inspect).not_to include('raw-oauth-secret')
    end

    it 'treats the token as gone after 30 minutes' do
      authorize_todoist

      travel 31.minutes do
        get todoist_projects_path(diet_set_ids: ['1'])
      end

      expect(response).to redirect_to(profile_path)
      expect(Todoist::Api).not_to have_received(:fetch_projects)
    end
  end
end
