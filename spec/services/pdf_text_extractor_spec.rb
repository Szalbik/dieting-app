# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PdfTextExtractor do
  subject(:extractor) { described_class.new('/tmp/example.pdf') }

  let(:pdf_reader_pages) do
    [
      PdfTextExtractor::Page.new(page_number: 1, text: "Dzien 1\nSniadanie\nJogurt naturalny 150g\nPłatki owsiane 20g"),
    ]
  end

  describe '#call' do
    it 'returns embedded PDF text when it is substantial enough' do
      pdf_text = "Dzien 1\nSniadanie\nJogurt naturalny 150g\nPłatki owsiane 20g"
      allow(extractor).to receive(:extract_text_with_pdf_reader).and_return(pdf_reader_pages)
      allow(extractor).to receive(:extract_text_with_pdftotext)
      allow(extractor).to receive(:extract_text_with_ocr)

      expect(extractor.call).to eq(pdf_text)
      expect(extractor).not_to have_received(:extract_text_with_pdftotext)
      expect(extractor).not_to have_received(:extract_text_with_ocr)
    end

    it 'falls back to OCR when PDF text layer is empty' do
      allow(extractor).to receive(:extract_text_with_pdf_reader).and_return([])
      allow(extractor).to receive(:extract_text_with_pdftotext).and_return([])
      allow(extractor).to receive(:extract_text_with_ocr).and_return([
        PdfTextExtractor::Page.new(page_number: 1, text: "Dzien 1\nSniadanie\nJogurt naturalny 150g"),
      ])

      expect(extractor.call).to eq("Dzien 1\nSniadanie\nJogurt naturalny 150g")
      expect(extractor).to have_received(:extract_text_with_ocr)
    end

    it 'falls back to OCR when text layer is too sparse for the page count' do
      allow(extractor).to receive(:extract_text_with_pdf_reader).and_return([
        PdfTextExtractor::Page.new(page_number: 1, text: 'abc'),
        PdfTextExtractor::Page.new(page_number: 2, text: ''),
      ])
      allow(extractor).to receive(:extract_text_with_pdftotext).and_return([])
      allow(extractor).to receive(:extract_text_with_ocr).and_return([
        PdfTextExtractor::Page.new(page_number: 1, text: "Dzien 1\nObiad\nKurczak 200g"),
      ])

      expect(extractor.call).to eq("Dzien 1\nObiad\nKurczak 200g")
    end

    it 'uses pdftotext before OCR when it can recover the text layer' do
      pdftotext_text = "Dzien 1\nSniadanie\nJogurt naturalny 150g\nPłatki owsiane 20g\nHerbata 250ml\nPomidor 1 szt\nSałata"

      allow(extractor).to receive(:extract_text_with_pdf_reader).and_return([
        PdfTextExtractor::Page.new(page_number: 1, text: 'abc'),
      ])
      allow(extractor).to receive(:extract_text_with_pdftotext).and_return([
        PdfTextExtractor::Page.new(page_number: 1, text: pdftotext_text),
      ])
      allow(extractor).to receive(:extract_text_with_ocr)

      expect(extractor.call).to eq(pdftotext_text)
      expect(extractor).not_to have_received(:extract_text_with_ocr)
    end
  end

  describe '#extract' do
    it 'returns the extraction source metadata' do
      ocr_pages = [
        PdfTextExtractor::Page.new(page_number: 1, text: "Dzien 1\nObiad\nKurczak 200g"),
      ]
      allow(extractor).to receive(:extract_text_with_pdf_reader).and_return([])
      allow(extractor).to receive(:extract_text_with_pdftotext).and_return([])
      allow(extractor).to receive(:extract_text_with_ocr).and_return(ocr_pages)

      result = extractor.extract

      expect(result.text).to eq("Dzien 1\nObiad\nKurczak 200g")
      expect(result.source).to eq(:ocr)
      expect(result.page_count).to eq(1)
      expect(result.pages).to eq(ocr_pages)
    end
  end
end
