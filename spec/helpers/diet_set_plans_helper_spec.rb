# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DietSetPlansHelper do
  include ActiveSupport::Testing::TimeHelpers

  describe '#meal_status_for' do
    let(:meal) { Struct.new(:name, :eaten?).new('Kolacja', false) } # 18:00 - 19:00

    it 'is :upcoming after the time window when not eaten' do
      travel_to(Time.zone.parse('2026-10-12 21:49')) do
        expect(helper.meal_status_for(meal, Date.current)).to eq(:upcoming)
      end
    end

    it 'is :current inside the time window' do
      travel_to(Time.zone.parse('2026-10-12 18:30')) do
        expect(helper.meal_status_for(meal, Date.current)).to eq(:current)
      end
    end

    it 'is :done when eaten' do
      meal[:eaten?] = true
      expect(helper.meal_status_for(meal, Date.current)).to eq(:done)
    end
  end
end
