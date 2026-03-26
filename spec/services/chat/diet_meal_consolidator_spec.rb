# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::DietMealConsolidator do
  describe '#call' do
    it 'merges accessory beverages into the preceding meal and keeps five meals for the day' do
      days = [
        {
          'day' => 3,
          'meals' => [
            meal(type: 'breakfast', name: 'Pieczywo razowe z jajkiem i pomidorem', kcal: 210),
            meal(type: 'snack', name: 'DRENANAT INSTANT', product: 'DRENANAT INSTANT', quantity: '1 filiżanka', kcal: 2),
            meal(type: 'snack', name: 'Gruszka z jogurtem i Fibroki', kcal: 120),
            meal(type: 'lunch', name: 'Roladki drobiowe z cukinią, mizeria z jogurtem', kcal: 226),
            meal(type: 'snack', name: 'Jogurt naturalny z Fibroki', kcal: 80),
            meal(type: 'dinner', name: 'Sałatka z gruszką, rukolą, fetą, pomidorem i sosem balsamicznym', kcal: 220),
            meal(type: 'snack', name: 'DRENANAT INSTANT', product: 'DRENANAT INSTANT', quantity: '1 filiżanka', kcal: 2)
          ]
        }
      ]

      consolidated_day = described_class.new(days).call.first

      expect(consolidated_day['meals'].size).to eq(5)
      expect(consolidated_day['meals'].first['name']).to include('DRENANAT INSTANT')
      expect(consolidated_day['meals'].first.dig('nutrition', 'kcal')).to eq(212)
      expect(consolidated_day['meals'].last['name']).to include('DRENANAT INSTANT')
      expect(consolidated_day['meals'].last.dig('nutrition', 'kcal')).to eq(222)
    end

    it 'collapses fragmented dinner rows into a single dinner meal' do
      days = [
        {
          'day' => 1,
          'meals' => [
            meal(type: 'breakfast', name: 'Płatki owsiane Dietesse z mlekiem', kcal: 220),
            meal(type: 'snack', name: 'Koktajl z melonem i selerem', kcal: 110),
            meal(type: 'lunch', name: 'Sałatka z pomidorami i rukolą', kcal: 90),
            meal(type: 'snack', name: 'INFUNAT TE ROJO', product: 'INFUNAT TE ROJO', quantity: '1 porcja', kcal: 2),
            meal(type: 'snack', name: 'Melon lub ananas', kcal: 60),
            meal(type: 'dinner', name: 'Sałatka z tuńczykiem', kcal: 170),
            meal(type: 'snack', name: 'Jogurt naturalny z Fibroki', kcal: 80),
            meal(type: 'snack', name: 'INFUNAT TE ROJO', product: 'INFUNAT TE ROJO', quantity: '1 porcja', kcal: 2),
            meal(type: 'dinner', name: 'Indyk w ziołach', kcal: 260)
          ]
        }
      ]

      consolidated_day = described_class.new(days).call.first

      expect(consolidated_day['meals'].size).to eq(5)
      expect(consolidated_day['meals'][2]['name']).to include('INFUNAT TE ROJO')
      expect(consolidated_day['meals'].last['name']).to include('Sałatka z tuńczykiem')
      expect(consolidated_day['meals'].last['name']).to include('Indyk w ziołach')
      expect(consolidated_day['meals'].last.dig('nutrition', 'kcal')).to eq(512)
    end
  end

  def meal(type:, name:, kcal:, product: nil, quantity: '1 porcja')
    {
      'type' => type,
      'name' => name,
      'ingredients' => [
        {
          'product' => product || name,
          'quantity' => quantity
        }
      ],
      'instructions' => '',
      'nutrition' => {
        'kcal' => kcal,
        'protein' => 0,
        'fat' => 0,
        'carbs' => 0
      }
    }
  end
end
