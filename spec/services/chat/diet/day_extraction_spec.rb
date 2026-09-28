# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::DayExtraction do
  describe '.in_parallel' do
    it 'preserves input order and never runs more than `concurrency` items at once' do
      running = Concurrent::AtomicFixnum.new(0)
      peak = Concurrent::AtomicFixnum.new(0)

      result = described_class.in_parallel(1..6, 2) do |n|
        now = running.increment
        peak.update { |p| [p, now].max }
        sleep 0.01
        running.decrement
        n * 10
      end

      expect(result).to eq([10, 20, 30, 40, 50, 60])
      expect(peak.value).to be <= 2
    end

    it 'lets sibling threads finish before re-raising the first failure' do
      finished = Concurrent::AtomicFixnum.new(0)

      expect do
        described_class.in_parallel(%w[a b c], 3) do |item|
          raise "boom #{item}" if item == 'a'

          sleep 0.02
          finished.increment
        end
      end.to raise_error('boom a')

      expect(finished.value).to eq(2)
    end
  end

  describe '.day_schema' do
    it 'requires a category per ingredient, limited to the seeded categories' do
      create(:category, name: 'Warzywa')
      create(:category, name: 'Inne')

      ingredient = described_class.day_schema.dig('properties', 'meals', 'items', 'properties', 'ingredients', 'items')

      expect(ingredient['required']).to include('category')
      expect(ingredient.dig('properties', 'category', 'enum')).to contain_exactly('Warzywa', 'Inne')
      expect(described_class::DAY_SCHEMA.dig('properties', 'meals', 'items', 'properties', 'ingredients', 'items',
                                             'required')).not_to include('category')
    end

    it 'falls back to "Inne" when no categories are seeded' do
      ingredient = described_class.day_schema.dig('properties', 'meals', 'items', 'properties', 'ingredients', 'items')

      expect(ingredient.dig('properties', 'category', 'enum')).to eq(['Inne'])
    end
  end

  describe '.chat_params' do
    it 'keeps temperature only for non-reasoning models or effort none' do
      expect(described_class.chat_params(model: 'gpt-4.1', reasoning_effort: 'low')).to eq(temperature: 0.2)
      expect(described_class.chat_params(model: 'gpt-5.1', reasoning_effort: nil))
        .to eq(reasoning_effort: 'none', temperature: 0.2)
      expect(described_class.chat_params(model: 'gpt-5.1', reasoning_effort: 'medium'))
        .to eq(reasoning_effort: 'medium')
    end
  end
end
