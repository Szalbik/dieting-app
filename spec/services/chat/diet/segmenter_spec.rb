# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::Segmenter do
  subject(:segments) { described_class.new(pages).call }

  let(:pages) do
    [
      PdfTextExtractor::Page.new(
        page_number: 1,
        text: <<~TEXT
          Zestaw 1

          1) Śniadanie
          Kanapki
          -chleb razowy -2kromki (70g)

          2) Obiad
          Pad Thai
          -mięso z piersi kurczaka (150g)
        TEXT
      ),
      PdfTextExtractor::Page.new(
        page_number: 2,
        text: <<~TEXT
          -makaron ryżowy (45g)

          Sposób wykonania:
          1. Wymieszaj składniki.

          Zestaw 2

          1) Śniadanie
          Omlet
          -jaja -2szt. (100g)
        TEXT
      ),
    ]
  end

  it 'detects multiple days and keeps a cross-page recipe in one segment' do
    expect(segments.map(&:day_number)).to eq([1, 1, 2])
    expect(segments.second.page_numbers).to eq([1, 2])
    expect(segments.second.text).to include('Pad Thai')
    expect(segments.second.text).to include('Sposób wykonania')
    expect(segments.third.text).to include('Omlet')
  end
end
