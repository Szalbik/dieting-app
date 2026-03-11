# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Local::CanonicalProductResolver do
  let(:user) { create(:user) }
  let(:resolver) { described_class.new(user: user) }

  describe '#call' do
    it 'reuses the same canonical product for inflected aliases' do
      canonical = resolver.call(raw_name: 'Jabłko')
      inflected = resolver.call(raw_name: 'jabłka')

      expect(inflected.id).to eq(canonical.id)
      expect(canonical.canonical_product_aliases.pluck(:name)).to include('Jabłko', 'jabłka')
    end

    it 'prefers an existing diet product label as canonical name' do
      diet = create(:diet, user: user)
      diet_set = create(:diet_set, diet: diet)
      meal = create(:meal, diet_set: diet_set)
      create(:product, meal: meal, diet_set: diet_set, name: 'Bułka grahamka')

      canonical = resolver.call(raw_name: 'bułki graham')

      expect(canonical.name).to eq('Bułka grahamka')
    end
  end
end
