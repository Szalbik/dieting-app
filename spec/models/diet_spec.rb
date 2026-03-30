# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Diet, type: :model do
  describe 'validations' do
    subject { build(:diet) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:user_id) }

    it 'allows meals_per_day to be nil' do
      diet = build(:diet, meals_per_day: nil)
      expect(diet).to be_valid
    end

    it 'rejects meals_per_day below 1' do
      diet = build(:diet, meals_per_day: 0)
      expect(diet).not_to be_valid
      expect(diet.errors[:meals_per_day]).to be_present
    end

    it 'rejects meals_per_day above 10' do
      diet = build(:diet, meals_per_day: 11)
      expect(diet).not_to be_valid
      expect(diet.errors[:meals_per_day]).to be_present
    end

    it 'accepts meals_per_day in 1..10' do
      diet = build(:diet, meals_per_day: 7)
      expect(diet).to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:diet_sets).dependent(:destroy) }
  end
end
