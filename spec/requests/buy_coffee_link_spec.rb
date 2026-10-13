# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Navbar Buy Me a Coffee link', type: :request do
  let(:user) { create(:user, password: 'password123', password_confirmation: 'password123') }

  it "links to the app's own account" do
    post session_path, params: { email_address: user.email_address, password: 'password123' }
    get profile_path

    expect(response.body).to include('https://buymeacoffee.com/asystentdiet')
    expect(response.body).not_to include('rubydive')
  end
end
