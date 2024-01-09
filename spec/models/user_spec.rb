# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build :user }

    it { is_expected.to be_valid }
  end

  describe 'associations' do
    it { is_expected.to have_many(:products) }
  end
end
