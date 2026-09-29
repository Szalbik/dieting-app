# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietSetPlan, type: :model do
  describe 'servings' do
    it 'defaults to 1' do
      expect(create(:diet_set_plan).servings).to eq(1)
    end

    it 'accepts the 1..10 range' do
      expect(build(:diet_set_plan, servings: 1)).to be_valid
      expect(build(:diet_set_plan, servings: 10)).to be_valid
    end

    it 'rejects 0, 11 and non-integers' do
      [0, 11, 1.5].each do |value|
        expect(build(:diet_set_plan, servings: value)).not_to be_valid
      end
    end
  end
end
