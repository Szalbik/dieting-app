# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#ai_operations' do
    it 'declines the Polish accusative by count' do
      expected = ['1 operację AI', '3 operacje AI', '5 operacji AI', '12 operacji AI', '22 operacje AI',
                  '25 operacji AI']
      expect([1, 3, 5, 12, 22, 25].map { |n| helper.ai_operations(n) }).to eq(expected)
    end

    it 'capitalizes on request' do
      expect(helper.ai_operations(3, capitalize: true)).to eq('3 Operacje AI')
    end
  end

  describe '#pro_price' do
    it 'formats the monthly price with a Polish decimal comma' do
      expect(helper.pro_price(:monthly)).to eq('19,90 zł')
    end

    it 'drops zero decimals for the yearly price' do
      expect(helper.pro_price(:yearly)).to eq('199 zł')
    end

    it 'shows the yearly price per month for comparison' do
      expect(helper.pro_price(:yearly, per_month: true)).to eq('16,58 zł')
    end
  end
end
