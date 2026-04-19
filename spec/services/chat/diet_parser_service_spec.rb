# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::DietParserService do
  subject(:service) { described_class.new('/tmp/example.pdf', expected_meals_per_day: 5) }

  it 'delegates to the new staged parsing pipeline' do
    pipeline = instance_double(Chat::Diet::ParsingPipeline, call: [{ 'day' => 1, 'meals' => [] }])

    allow(Chat::Diet::ParsingPipeline).to receive(:new).with(
      '/tmp/example.pdf',
      expected_meals_per_day: 5
    ).and_return(pipeline)

    expect(service.call).to eq([{ 'day' => 1, 'meals' => [] }])
  end
end
