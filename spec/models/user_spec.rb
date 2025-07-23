# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
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
      expect(user.errors[:password]).to include('is too short (minimum is 6 characters)')
    end

    it 'validates password confirmation' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
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
end
