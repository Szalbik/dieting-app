# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::DaySegmenter do
  subject(:chunks) { described_class.new(pages).call }

  let(:pages) do
    [
      PdfTextExtractor::Page.new(
        page_number: 1,
        text: <<~TEXT
          ## Zestaw 1

          |Śniadanie|Obiad|
          |---|---|

          ## 1) Śniadanie
          Kanapki
          -chleb razowy -2kromki (70g)
        TEXT
      ),
      PdfTextExtractor::Page.new(
        page_number: 2,
        text: <<~TEXT
          ## 2) Obiad
          Pad Thai
          -mięso z piersi kurczaka (150g)
          Sposób wykonania:
          1. Wymieszaj składniki.

          ## Zestaw 2

          ## 1) Śniadanie
          Omlet
          -jaja -2szt. (100g)
        TEXT
      )
    ]
  end

  it 'splits into one chunk per day, tracking contributing pages' do
    expect(chunks.map(&:day)).to eq([1, 2])
    expect(chunks.first.page_numbers).to eq([1, 2])
    expect(chunks.first.markdown).to include('Pad Thai')
    expect(chunks.first.markdown).to include('Sposób wykonania')
    expect(chunks.second.page_numbers).to eq([2])
    expect(chunks.second.markdown).to include('Omlet')
  end

  context 'when day headings are wrapped in markdown emphasis' do
    # Regression: "**_Zestaw 2_**" has an underscore directly touching both
    # "Zestaw" and "2" (PyMuPDF4LLM's bold+italic heading style). Underscore
    # is a \w character, so a naive \b-anchored regex silently fails to
    # match and the whole PDF collapses into a single day.
    let(:pages) do
      [
        PdfTextExtractor::Page.new(page_number: 1, text: "## **_Zestaw 1_** \n\n## **_1) Śniadanie_** \nOmlet"),
        PdfTextExtractor::Page.new(page_number: 2, text: "## **_Zestaw 2_** \n\n## **_1) Śniadanie_** \nJajecznica"),
      ]
    end

    it 'still detects each day' do
      expect(chunks.map(&:day)).to eq([1, 2])
      expect(chunks.first.markdown).to include('Omlet')
      expect(chunks.second.markdown).to include('Jajecznica')
    end
  end

  context 'when no day marker is present' do
    let(:pages) do
      [PdfTextExtractor::Page.new(page_number: 1, text: "## 1) Śniadanie\nOmlet")]
    end

    it 'falls back to a single day 1 chunk containing the whole document' do
      expect(chunks.size).to eq(1)
      expect(chunks.first.day).to eq(1)
      expect(chunks.first.markdown).to include('Omlet')
      expect(chunks.first.page_numbers).to eq([1])
    end
  end
end
