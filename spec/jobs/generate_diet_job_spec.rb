# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateDietJob, type: :job do
  let(:diet) { create(:diet, source: 'generated', status: 'generating', kcal_target: 2000) }

  describe '#perform' do
    it 'stores the parsed days and enqueues population on success' do
      days = [{ 'day' => 1, 'meals' => [] }]
      service = instance_double(Chat::DietGeneratorService, call: days)
      allow(Chat::DietGeneratorService).to receive(:new).with(diet).and_return(service)

      expect { described_class.new.perform(diet.id) }
        .to have_enqueued_job(PopulateDietFromJsonJob).with(diet.id)

      expect(diet.reload.parsed_json).to eq(days)
    end

    it 'records the failure and re-raises when generation errors' do
      service = instance_double(Chat::DietGeneratorService)
      allow(Chat::DietGeneratorService).to receive(:new).with(diet).and_return(service)
      allow(service).to receive(:call).and_raise('OpenAI API error: boom')

      expect { described_class.new.perform(diet.id) }.to raise_error('OpenAI API error: boom')

      diet.reload
      expect(diet.status).to eq('failed')
      expect(diet.generation_error).to eq('OpenAI API error: boom')
    end
  end
end
