# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'docker-compose.yml' do # rubocop:disable RSpec/DescribeClass
  it 'publishes the dev Redis on loopback only' do
    compose = YAML.load_file(Rails.root.join('docker-compose.yml'))
    expect(compose.dig('services', 'redis', 'ports')).to eq(['127.0.0.1:63790:6379'])
  end
end
