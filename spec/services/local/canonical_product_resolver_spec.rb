# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Local::CanonicalProductResolver do
  let(:user) { create(:user) }
  let(:resolver) { described_class.new(user: user) }

  describe '#call' do
    it 'reuses the same canonical product for inflected aliases' do
      # 'jajko' and 'jajka' both lemmatize to 'jajko' via PolishLemmatizer::TOKEN_LEMMAS
      canonical = resolver.call(raw_name: 'Jajko').canonical_product
      inflected = resolver.call(raw_name: 'jajka').canonical_product

      expect(inflected.id).to eq(canonical.id)
      expect(canonical.canonical_product_aliases.pluck(:name)).to include('Jajko', 'jajka')
    end

    it 'resolves inflected forms to the same canonical via stem signature' do
      # PolishLemmatizer maps 'naturalnego' → 'naturalny' and 'naturalny' → 'naturalny',
      # so both produce the same stem signature and map to one canonical product.
      canonical = resolver.call(raw_name: 'Jogurt naturalny').canonical_product
      inflected = resolver.call(raw_name: 'jogurt naturalnego').canonical_product

      expect(inflected.id).to eq(canonical.id)
    end
  end
end
