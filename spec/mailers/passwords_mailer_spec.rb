# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PasswordsMailer do
  describe '#reset' do
    let(:user) { FactoryBot.create(:user) }
    let(:mail) { described_class.reset(user) }

    it 'is sent from the app domain to the user' do
      expect(mail.from).to eq(['no-reply@asystentdiet.pl'])
      expect(mail.to).to eq([user.email_address])
    end
  end
end
