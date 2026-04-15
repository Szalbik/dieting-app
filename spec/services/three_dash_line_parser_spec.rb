# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThreeDashLineParser do
  describe '#parse' do
    subject { described_class.new.parse(line) }

    context 'when line is a three dash line' do
      let(:line) { '-chleb razowy -2kromki (70g) lub chleb orkiszowy -2kromki (80g)' }

      it 'collects measurements from both alternatives joined by "lub"' do
        expect(subject).to match_array([
                                         'chleb razowy',
                                         match_array([[2.0, 'kromki'], [70.0, 'g'], [2.0, 'kromki'], [80.0, 'g']])
                                       ])
      end
    end

    # context 'when line is not a three dash line' do
    #   let(:line) { '' }
    #
    #   it {  }
    # end
  end
end
