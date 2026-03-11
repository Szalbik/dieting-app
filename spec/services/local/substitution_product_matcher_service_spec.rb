# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Local::SubstitutionProductMatcherService do
  describe '#call' do
    it 'matches inflected source names to diet product names' do
      service = described_class.new(
        source_products: [
          'jogurtu naturalnego 2% tłuszczu',
          'bułki graham',
          'ananasa'
        ],
        diet_product_names: [
          'Jogurt naturalny 2% tłuszczu',
          'Bułka grahamka',
          'Ananas z puszki',
          'Mleko 2%'
        ]
      )

      result = service.call

      jogurt = result.find { |row| row['source_product'] == 'jogurtu naturalnego 2% tłuszczu' }
      bulka = result.find { |row| row['source_product'] == 'bułki graham' }
      ananas = result.find { |row| row['source_product'] == 'ananasa' }

      expect(jogurt['matches'].map { |m| m['name'] }).to include('Jogurt naturalny 2% tłuszczu')
      expect(bulka['matches'].map { |m| m['name'] }).to include('Bułka grahamka')
      expect(ananas['matches'].map { |m| m['name'] }).to include('Ananas z puszki')
    end
  end
end
