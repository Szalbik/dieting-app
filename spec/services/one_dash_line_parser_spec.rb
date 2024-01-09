# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OneDashLineParser do
  describe '#parse' do
    subject { described_class.new.parse(line) }

    context 'with measurements in brackets as g' do
      let(:line) { 'Jogurt pitny Twist, brzoskwinia-mango -1szt. (380g) np. Bakoma' }

      it 'returns correct data' do
        expect(subject).to match_array(['Jogurt pitny Twist, brzoskwinia-mango', match_array([[1, 'szt'], [380, 'g']])])
      end
    end

    context 'with measurements in brackets as ml' do
      let(:line) { 'Herbata, gorzka -1szkl. (250ml)' }

      it 'returns correct data' do
        expect(subject).to match_array(['Herbata, gorzka', match_array([[1, 'szkl'], [250, 'ml']])])
      end
    end

    context 'with - at the beginning' do
      context 'case 1' do
        let(:line) { '-pstrąg strumieniowy (250g)' }

        it 'returns correct data' do
          expect(subject).to match_array(['pstrąg strumieniowy', match_array([[250, 'g']])])
        end
      end
      context 'case 2' do
        let(:line) { '-sól, pieprz, słodka mielona papryka' }

        it 'returns correct data' do
          expect(subject).to match_array(['sól, pieprz, słodka mielona papryka', nil])
        end
      end
    end
  end
end
