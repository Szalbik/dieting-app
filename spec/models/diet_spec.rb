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

  describe '#destroy' do
    it 'purges the uploaded PDF file, not just the attachment row' do
      diet = create(:diet, :with_pdf)
      expect { diet.destroy! }.to have_enqueued_job(ActiveStorage::PurgeJob)
    end

    it 'succeeds when a day holds a product pointing at it via diet_set_id' do
      diet = create(:diet)
      diet_set = create(:diet_set, diet: diet)
      product = create(:product, meal: create(:meal, diet_set: diet_set), diet_set: diet_set)

      expect { diet.destroy! }.to change(described_class, :count).by(-1)
      expect(product.reload.diet_set_id).to be_nil
    end
  end

  describe '#fail_generation!' do
    let(:user) { create(:user, ai_free_used_count: 1) }
    let(:diet) { create(:diet, user: user, source: 'pdf', status: 'generating') }

    it 'does not refund the quota when the failure comes from the user content' do
      diet.fail_generation!(RuntimeError.new('Parser nie znalazł dni diety w PDF.'))

      expect(diet.reload.status).to eq('failed')
      expect(user.reload.ai_free_used_count).to eq(1)
    end

    it 'refunds the quota when the provider failed' do
      diet.fail_generation!(Faraday::ServerError.new('503'))

      expect(diet.reload.status).to eq('failed')
      expect(user.reload.ai_free_used_count).to eq(0)
    end

    it 'never refunds twice for the same diet' do
      diet.fail_generation!(Faraday::ServerError.new('503'))
      diet.fail_generation!(Faraday::ServerError.new('503'))

      expect(user.reload.ai_free_used_count).to eq(0)
    end
  end

  describe '#parse_pdf_content_with_chat!' do
    it 'saves parsed_json returned by the parser service' do
      diet = create(:diet, :with_pdf)
      parsed_data = [{ 'day' => 1, 'meals' => [] }]
      parser = instance_double(Chat::DietParserService, call: parsed_data)

      allow(Chat::DietParserService).to receive(:new).and_return(parser)

      diet.parse_pdf_content_with_chat!

      expect(diet.reload.parsed_json).to eq(parsed_data)
    end
  end
end
