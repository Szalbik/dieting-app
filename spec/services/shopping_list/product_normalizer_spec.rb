# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShoppingList::ProductNormalizer do
  subject(:normalizer) { described_class.new }

  describe '#call' do
    it 'returns the same key for Polish inflected variants' do
      forms = %w[jajko jajka jajek jaja].map { |name| normalizer.call(raw_name: name)[:key] }

      expect(forms.uniq).to eq(['jajko'])
    end

    it 'does not merge unrelated products' do
      jajko = normalizer.call(raw_name: 'jajko')[:key]
      pomidor = normalizer.call(raw_name: 'pomidor')[:key]

      expect(jajko).not_to eq(pomidor)
    end

    it 'handles multi-word names without losing important tokens' do
      result = normalizer.call(raw_name: '  mleka kokosowego ')

      expect(result[:key]).to eq('mleko kokosowy')
      expect(result[:display_name]).to eq('mleka kokosowego')
      expect(result[:normalized_tokens]).to eq(%w[mleko kokosowy])
    end

    it 'preserves non-quantity parentheses in the display label' do
      result = normalizer.call(raw_name: 'tymianek (świeży lub suszony)')

      expect(result[:display_name]).to eq('tymianek (świeży lub suszony)')
      expect(result[:key]).to include('tymianek')
    end

    it 'repairs a missing closing parenthesis in malformed labels' do
      result = normalizer.call(raw_name: 'tymianek (świeży lub suszony')

      expect(result[:display_name]).to eq('tymianek (świeży lub suszony)')
    end

    it 'falls back safely when the lemmatizer raises' do
      lemmatizer = instance_double(ShoppingList::PolishLemmatizer)
      allow(lemmatizer).to receive(:lemma).and_raise(StandardError, 'boom')
      fallback_normalizer = described_class.new(lemmatizer: lemmatizer)

      result = fallback_normalizer.call(raw_name: 'Pomidor')

      expect(result[:key]).to eq('pomidor')
      expect(result[:display_name]).to eq('Pomidor')
      expect(result[:normalized_tokens]).to eq(['pomidor'])
    end
  end

  describe '#best_display_label' do
    it 'prefers a nominative-like readable label when available' do
      label = normalizer.best_display_label(%w[Jajka Jajko jaja])

      expect(label).to eq('Jajko')
    end
  end
end
