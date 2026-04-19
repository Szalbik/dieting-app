# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin dietitian waitlist', type: :request do
  let(:password) { 'password123' }
  let(:waitlist_entry) { create(:dietitian_waitlist_entry) }
  let(:admin_user) { create(:user, :admin, password: password, password_confirmation: password) }
  let(:regular_user) { create(:user, password: password, password_confirmation: password) }

  def login(user)
    post session_path, params: { email_address: user.email_address, password: password }
  end

  describe 'GET /admin' do
    it 'redirects guests to sign in' do
      get admin_root_path

      expect(response).to redirect_to(new_session_path)
    end

    it 'redirects non-admin users away from the panel' do
      login(regular_user)

      get admin_root_path

      expect(response).to redirect_to(root_path)
    end

    it 'renders the dashboard for admins' do
      waitlist_entry
      login(admin_user)

      get admin_root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Dietitian beta applications')
    end
  end

  describe 'GET /admin/dietitian_waitlist_entries' do
    it 'shows the waitlist resource for admins' do
      waitlist_entry
      login(admin_user)

      get admin_dietitian_waitlist_entries_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(waitlist_entry.email_address)
    end
  end

  describe 'PATCH /admin/dietitian_waitlist_entries/:id' do
    it 'updates status and notes for admins' do
      login(admin_user)

      patch admin_dietitian_waitlist_entry_path(waitlist_entry), params: {
        dietitian_waitlist_entry: {
          status: 'approved',
          notes: 'Strong fit after demo'
        }
      }

      expect(response).to redirect_to(admin_dietitian_waitlist_entry_path(waitlist_entry))
      expect(waitlist_entry.reload).to be_approved
      expect(waitlist_entry.notes).to eq('Strong fit after demo')
      expect(waitlist_entry.approved_at).to be_present
    end
  end
end
