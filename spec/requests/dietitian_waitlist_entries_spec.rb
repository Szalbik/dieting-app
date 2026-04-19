# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dietitian waitlist entries', type: :request do
  describe 'GET /dietitian-waitlist/new' do
    it 'renders the waitlist form' do
      get new_dietitian_waitlist_entry_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Join the waitlist')
    end
  end

  describe 'POST /dietitian-waitlist' do
    let(:valid_params) do
      {
        dietitian_waitlist_entry: {
          first_name: 'Anna',
          email_address: 'anna@clinic.com',
          company_name: 'Healthy Clinic'
        }
      }
    end

    it 'creates a waitlist entry with valid params' do
      expect do
        post dietitian_waitlist_entries_path, params: valid_params
      end.to change(DietitianWaitlistEntry, :count).by(1)

      expect(response).to redirect_to(new_dietitian_waitlist_entry_path)
      follow_redirect!
      expect(response.body).to include('Join the waitlist')
    end

    it 'does not create an entry with invalid email' do
      invalid_params = valid_params.deep_dup
      invalid_params[:dietitian_waitlist_entry][:email_address] = 'bad_email'

      expect do
        post dietitian_waitlist_entries_path, params: invalid_params
      end.not_to change(DietitianWaitlistEntry, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Please check the form')
    end

    it 'does not create an entry when required fields are missing' do
      invalid_params = { dietitian_waitlist_entry: { first_name: '', email_address: '', company_name: '' } }

      expect do
        post dietitian_waitlist_entries_path, params: invalid_params
      end.not_to change(DietitianWaitlistEntry, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects duplicate email addresses' do
      create(:dietitian_waitlist_entry, email_address: valid_params[:dietitian_waitlist_entry][:email_address])

      expect do
        post dietitian_waitlist_entries_path, params: valid_params
      end.not_to change(DietitianWaitlistEntry, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
