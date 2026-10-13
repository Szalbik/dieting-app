# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#pro_price' do
    it 'formats the monthly price with a Polish decimal comma' do
      expect(helper.pro_price(:monthly)).to eq('19,90 zł')
    end

    it 'drops zero decimals for the yearly price' do
      expect(helper.pro_price(:yearly)).to eq('199 zł')
    end
  end
end
