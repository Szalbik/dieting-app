# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietBuilderJob, type: :job do
  let(:user) { create(:user, ai_quota_used_count: 1, ai_quota_period_started_at: Time.current.beginning_of_month) }
  let(:diet) { create(:diet, :with_pdf, user: user, source: 'pdf', status: 'generating') }
  let(:parser) { instance_double(Chat::DietParserService) }

  before { allow(Chat::DietParserService).to receive(:new).and_return(parser) }

  describe '#perform' do
    it 'stores parsed days and enqueues population on success' do
      days = [{ 'day' => 1, 'meals' => [] }]
      allow(parser).to receive(:call).and_return(days)

      expect { described_class.new.perform(diet.id) }
        .to have_enqueued_job(PopulateDietFromJsonJob).with(diet.id)

      expect(diet.reload.parsed_json).to eq(days)
      expect(user.reload.ai_quota_used_count).to eq(1)
    end

    it 'marks the diet failed, refunds the quota and re-raises when parsing errors' do
      allow(parser).to receive(:call).and_raise('OpenAI API error: boom')

      expect { described_class.new.perform(diet.id) }.to raise_error('OpenAI API error: boom')

      diet.reload
      expect(diet.status).to eq('failed')
      expect(diet.generation_error).to eq('OpenAI API error: boom')
      expect(user.reload.ai_quota_used_count).to eq(0)
    end

    it 'does not refund a second time when an already-failed job is retried by hand' do
      allow(parser).to receive(:call).and_raise('still broken')
      diet.update!(status: 'failed')
      user.update!(ai_quota_used_count: 0)

      expect { described_class.new.perform(diet.id) }.to raise_error('still broken')

      expect(user.reload.ai_quota_used_count).to eq(0)
      expect(diet.reload.generation_error).to eq('still broken')
    end

    it 'treats an empty parse as a failure instead of silently skipping population' do
      allow(parser).to receive(:call).and_return([])

      expect do
        expect { described_class.new.perform(diet.id) }.to raise_error(RuntimeError, /nie znalazł posiłków/)
      end.not_to have_enqueued_job(PopulateDietFromJsonJob)

      expect(diet.reload.status).to eq('failed')
      expect(user.reload.ai_quota_used_count).to eq(0)
    end
  end
end
