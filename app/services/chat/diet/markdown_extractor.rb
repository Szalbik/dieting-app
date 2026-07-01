# frozen_string_literal: true

require 'json'
require 'open3'

# PDF -> per-page Markdown, preserving table structure (meal/ingredient/nutrition
# tables flatten badly as plain text). Shells out to bin/pdf_to_markdown.py
# (PyMuPDF4LLM), same pattern as PdfTextExtractor's pdftotext/tesseract calls.
# Falls back to PdfTextExtractor (text -> OCR tiers) for scanned PDFs where
# markdown extraction yields too little text.
class Chat::Diet::MarkdownExtractor
  SCRIPT_PATH = Rails.root.join('bin', 'pdf_to_markdown.py').freeze

  def initialize(file_path)
    @file_path = file_path
  end

  def extract
    pages = extract_markdown_pages
    text = join_pages(pages)
    page_count = pages.size

    if PdfTextExtractor.sufficient_text?(text, page_count)
      PdfTextExtractor::Result.new(text: text, page_count: page_count, source: :markdown, pages: pages)
    else
      PdfTextExtractor.new(@file_path).extract
    end
  end

  private

  def extract_markdown_pages
    return [] unless command_available?('python3')

    stdout, stderr, status = Open3.capture3('python3', SCRIPT_PATH.to_s, @file_path.to_s)
    raise "pdf_to_markdown.py failed: #{stderr}" unless status.success?

    JSON.parse(stdout).map do |page|
      PdfTextExtractor::Page.new(page_number: page['page'], text: page['text'].to_s)
    end
  rescue StandardError
    []
  end

  def join_pages(pages)
    Array(pages).map(&:text).reject(&:blank?).join("\n\n")
  end

  def command_available?(name)
    system('which', name, out: File::NULL, err: File::NULL)
  end
end
