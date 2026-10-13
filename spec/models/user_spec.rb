# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe 'consents' do
    let(:user) { build :user }

    it 'starts with no consents' do
      expect(user.consented?(:terms)).to be(false)
    end

    it 'records a consent with its acceptance time, keyed by string' do
      freeze_time do
        user.record_consent(:parse_disclaimer)
        expect(user.consents).to eq('parse_disclaimer' => Time.current.iso8601)
        expect(user.consented?('parse_disclaimer')).to be(true)
      end
    end

    it 'persists a consent even when the record would fail validation' do
      user = create :user
      user.update_column(:email_address, 'legacy-invalid') # rubocop:disable Rails/SkipsModelValidations
      user.reload.record_consent!(:parse_disclaimer)
      expect(user.reload.consented?(:parse_disclaimer)).to be(true)
    end
  end

  describe 'validations' do
    subject { build :user }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
    it { is_expected.to allow_value('user@example.com').for(:email_address) }
    it { is_expected.not_to allow_value('invalid_email').for(:email_address) }

    it 'validates password length' do
      user = build(:user, password: 'short', password_confirmation: 'short')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'validates password confirmation' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to be_present
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:products) }
  end

  describe 'security' do
    it 'has secure password' do
      user = build(:user, password: 'password123', password_confirmation: 'password123')
      expect(user).to respond_to(:authenticate)
    end
  end

  describe 'data isolation' do
    it 'ensures users cannot access each other\'s diets' do
      user1 = FactoryBot.create(:user)
      user2 = FactoryBot.create(:user)
      diet1 = FactoryBot.create(:diet, user: user1)
      diet2 = FactoryBot.create(:diet, user: user2)
      expect(user1.diets).to include(diet1)
      expect(user1.diets).not_to include(diet2)
      expect(user2.diets).to include(diet2)
      expect(user2.diets).not_to include(diet1)
    end
  end

  describe 'profile fields' do
    subject { build :user }

    it 'has a first_name field' do
      user = build(:user, first_name: 'Alice')
      expect(user.first_name).to eq('Alice')
    end

    it 'can be set via the factory' do
      user = build(:user)
      expect(user.first_name).to be_present
    end
  end

  describe '#subscribed?' do
    it 'is true when subscription is active' do
      user = build(:user, subscription: :active)
      expect(user).to be_subscribed
    end

    it 'is true when subscription is lifetime' do
      user = build(:user, subscription: :lifetime)
      expect(user).to be_subscribed
    end

    it 'is true when inactive but subscription_end_date is in the future' do
      user = build(:user, subscription: :inactive, subscription_end_date: 1.day.from_now)
      expect(user).to be_subscribed
    end

    it 'is false when inactive with no end date' do
      user = build(:user, subscription: :inactive, subscription_end_date: nil)
      expect(user).not_to be_subscribed
    end

    it 'is false when inactive and end date is in the past' do
      user = build(:user, subscription: :inactive, subscription_end_date: 1.day.ago)
      expect(user).not_to be_subscribed
    end
  end

  describe '#ai_quota_available?' do
    it 'allows a free user 3 ops in total, then blocks' do
      user = create(:user, ai_free_used_count: 2)
      expect(user).to be_ai_quota_available
      user.update!(ai_free_used_count: 3)
      expect(user).not_to be_ai_quota_available
    end

    it 'never resets the free limit with a new month' do
      user = create(:user, ai_free_used_count: 3, ai_quota_period_started_at: 2.months.ago.beginning_of_month)
      expect(user).not_to be_ai_quota_available
    end

    it 'allows a Pro user up to 20 ops per month before blocking' do
      user = create(:user, subscription: :active, ai_free_used_count: 3, ai_quota_used_count: 19,
                           ai_quota_period_started_at: Time.current.beginning_of_month)
      expect(user).to be_ai_quota_available
      user.update!(ai_quota_used_count: 20)
      expect(user).not_to be_ai_quota_available
    end

    it 'resets the Pro limit once the period rolls into a new month' do
      user = create(:user, subscription: :active, ai_quota_used_count: 20,
                           ai_quota_period_started_at: 2.months.ago.beginning_of_month)
      expect(user).to be_ai_quota_available
    end

    it 'is always true for a lifetime user regardless of usage' do
      user = build(:user, subscription: :lifetime, ai_quota_used_count: 999, ai_free_used_count: 999,
                          ai_quota_period_started_at: Time.current.beginning_of_month)
      expect(user).to be_ai_quota_available
    end
  end

  describe '#refund_ai_quota!' do
    it 'gives back one consumed free op' do
      user = create(:user, ai_free_used_count: 1)
      user.refund_ai_quota!
      expect(user.reload.ai_free_used_count).to eq(0)
    end

    it 'gives back one consumed Pro op' do
      user = create(:user, subscription: :active, ai_quota_used_count: 1,
                           ai_quota_period_started_at: Time.current.beginning_of_month)
      user.refund_ai_quota!
      expect(user.reload.ai_quota_used_count).to eq(0)
    end

    it 'never goes below zero' do
      user = create(:user, ai_free_used_count: 0)
      user.refund_ai_quota!
      expect(user.reload.ai_free_used_count).to eq(0)
    end
  end

  describe '#consume_ai_quota!' do
    it 'increments the lifetime counter for a free user' do
      user = create(:user)
      user.consume_ai_quota!
      expect(user.reload).to have_attributes(ai_free_used_count: 1, ai_quota_used_count: 0)
    end

    it 'increments the monthly counter for a subscribed Pro user' do
      user = create(:user, subscription: :active)
      user.consume_ai_quota!
      expect(user.reload).to have_attributes(ai_free_used_count: 0, ai_quota_used_count: 1)
    end

    it 'resets the monthly counter before incrementing when the period is stale' do
      user = create(:user, subscription: :active, ai_quota_used_count: 5,
                           ai_quota_period_started_at: 2.months.ago.beginning_of_month)
      user.consume_ai_quota!
      expect(user.reload.ai_quota_used_count).to eq(1)
    end

    it 'does nothing for a lifetime user' do
      user = create(:user, subscription: :lifetime)
      user.consume_ai_quota!
      expect(user.reload).to have_attributes(ai_free_used_count: 0, ai_quota_used_count: 0)
    end
  end
end
