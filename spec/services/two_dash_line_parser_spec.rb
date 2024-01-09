# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TwoDashLineParser do
  describe '#parse' do
    subject { described_class.new.parse(line) }

    context 'with 2 dash line' do
      context 'with measurements in as dowolna ilość' do
        let(:line) { '-sałata lodowa -dowolna ilość' }

        it 'returns correct data' do
          expect(subject).to match_array(['sałata lodowa', nil])
        end
      end

      context 'with measurements in brackets as g' do
        let(:line) { '-jajka ugotowane na miękko -2szt. (100g)' }

        it 'returns correct data' do
          expect(subject).to match_array(['jajka ugotowane na miękko', match_array([[2, 'szt'], [100, 'g']])])
        end
      end

      context 'with measurements as szt' do
        context 'case 1' do
          let(:line) { '-jajka ugotowane na miękko -2szt. (100g)' }

          it 'returns correct data' do
            expect(subject).to match_array(['jajka ugotowane na miękko', match_array([[2, 'szt'], [100, 'g']])])
          end
        end
        context 'case 2' do
          let(:line) { '-serek ziarnisty typu grani -1szt. (200g)' }

          it 'returns correct data' do
            expect(subject).to match_array(['serek ziarnisty typu grani', match_array([[1, 'szt'], [200, 'g']])])
          end
        end
      end

      context 'with measurements as kromka' do
        let(:line) { '-chleb razowy -1 kromka (35g)' }

        it 'returns correct data' do
          expect(subject).to match_array(['chleb razowy', match_array([[1, 'kromka'], [35, 'g']])])
        end
      end

      context 'with measurements as łyżka' do
        let(:line) { '-keczup -1łyżka (15g)' }

        it 'returns correct data' do
          expect(subject).to match_array(['keczup', match_array([[1, 'łyżka'], [15, 'g']])])
        end
      end

      context 'with measurements as łyżeczka' do
        context 'case 1' do
          let(:line) { '-olej rzepakowy -1 łyżeczka (5ml)' }

          it 'returns correct data' do
            expect(subject).to match_array(['olej rzepakowy', match_array([[1, 'łyżeczka'], [5, 'ml']])])
          end
        end

        context 'case 2' do
          let(:line) { '-czosnek -4ząbki (16g)' }

          it 'returns correct data' do
            expect(subject).to match_array(['czosnek', match_array([[4, 'ząbki'], [16, 'g']])])
          end
        end
      end

      context 'with measurements as gałązki' do
        context 'case 1' do
          let(:line) { '-koperek -2 gałązki' }

          it 'returns correct data' do
            expect(subject).to match_array(['koperek', match_array([[2, 'gałązki']])])
          end
        end

        context 'case 2' do
          let(:line) { '-koperek -1 gałązka' }

          it 'returns correct data' do
            expect(subject).to match_array(['koperek', match_array([[1, 'gałązka']])])
          end
        end
      end

      context 'with measurements as ząbki' do
        context 'case 1' do
          let(:line) { '-olej rzepakowy -1 łyżeczka (5ml)' }

          it 'returns correct data' do
            expect(subject).to match_array(['olej rzepakowy', match_array([[1, 'łyżeczka'], [5, 'ml']])])
          end
        end
      end

      context 'with fraction of measurement' do
        context 'case 1' do
          let(:line) { '-cebula czerwona -1/2szt. (50g)' }

          it 'returns correct data' do
            expect(subject).to match_array(['cebula czerwona', match_array([[50, 'g']])])
          end
        end
        context 'case 2' do
          let(:line) { '-kasza orkiszowa -1/2 woreczka (50g)' }

          it 'returns correct data' do
            expect(subject).to match_array(['kasza orkiszowa', match_array([[50, 'g']])])
          end
        end
        context 'case 3' do
          let(:line) { '-cebula -1/2szt. (30g)' }

          it 'returns correct data' do
            expect(subject).to match_array(['cebula', match_array([[30, 'g']])])
          end
        end
      end
    end
  end
end
