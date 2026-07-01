# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chat::Diet::MarkdownExtractor do
  subject(:extractor) { described_class.new(fixture_path) }

  let(:fixture_path) { Rails.root.join('spec', 'fixtures', 'files', 'diet_for_one_week.pdf') }

  it 'converts the PDF to per-page markdown preserving table structure' do
    result = extractor.extract

    expect(result.source).to eq(:markdown)
    expect(result.page_count).to be_positive
    expect(result.text).to include('|---|')
    expect(result.pages).to all(be_a(PdfTextExtractor::Page))
  end

  context 'when markdown extraction yields insufficient text' do
    before do
      allow(PdfTextExtractor).to receive(:sufficient_text?).and_return(false)
      allow(PdfTextExtractor).to receive(:new).and_return(
        instance_double(PdfTextExtractor,
                        extract: PdfTextExtractor::Result.new(text: 'ocr text', page_count: 1, source: :ocr, pages: []))
      )
    end

    it 'falls back to PdfTextExtractor' do
      result = extractor.extract

      expect(result.source).to eq(:ocr)
    end
  end
end
