# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietitianWaitlistEntry, type: :model do
  subject(:entry) { build(:dietitian_waitlist_entry) }

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:company_name) }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to allow_value('dietitian@example.com').for(:email_address) }
    it { is_expected.not_to allow_value('invalid_email').for(:email_address) }

    it 'validates email uniqueness case insensitively' do
      create(:dietitian_waitlist_entry, email_address: 'dietitian@example.com')

      duplicate = build(:dietitian_waitlist_entry, email_address: 'DIETITIAN@example.com')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email_address]).not_to be_empty
    end
  end

  describe 'enums' do
    it 'defines the expected statuses' do
      expect(described_class.statuses.keys).to eq(%w[pending demo_scheduled demo_completed approved rejected])
    end
  end

  describe 'status timestamps' do
    it 'sets demo_called_at when moving to demo_completed' do
      fixed_time = Time.zone.parse('2026-04-19 12:00:00')
      allow(Time).to receive(:current).and_return(fixed_time)

      entry.update!(status: :demo_completed)

      expect(entry.demo_called_at).to eq(fixed_time)
    end

    it 'sets approved_at when moving to approved' do
      fixed_time = Time.zone.parse('2026-04-19 13:00:00')
      allow(Time).to receive(:current).and_return(fixed_time)

      entry.update!(status: :approved)

      expect(entry.approved_at).to eq(fixed_time)
    end

    it 'does not overwrite an existing approved_at value' do
      original_time = 2.days.ago
      entry = create(:dietitian_waitlist_entry, status: :approved, approved_at: original_time)

      allow(Time).to receive(:current).and_return(Time.zone.parse('2026-04-19 14:00:00'))

      entry.update!(notes: 'Followed up after approval')

      expect(entry.approved_at.to_i).to eq(original_time.to_i)
    end
  end
end
