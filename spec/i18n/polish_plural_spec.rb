# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Polish pluralization' do
  around { |example| I18n.with_locale(:pl) { example.run } }

  it 'picks one/few/many for diet set counts' do
    expected = { 0 => '0 zestawów', 1 => '1 zestaw', 2 => '2 zestawy', 5 => '5 zestawów',
                 12 => '12 zestawów', 22 => '22 zestawy' }

    expect(expected.keys.to_h { |n| [n, I18n.t('diets.sets_count', count: n)] }).to eq(expected)
  end

  it 'treats whole-number floats as integers and fractions as other' do
    expect(I18n.t('units.łyżka', count: 5)).to eq('łyżek')
    expect(I18n.t('units.łyżka', count: 2.0)).to eq('łyżki')
    expect(I18n.t('units.łyżka', count: 1.5)).to eq('łyżki')
  end
end
