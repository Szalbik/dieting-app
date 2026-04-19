# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'pdf-reader'

class PdfTextExtractor
  Page = Struct.new(:page_number, :text, keyword_init: true)
  Result = Struct.new(:text, :page_count, :source, :pages, keyword_init: true)

  MIN_TEXT_CHARS_PER_PAGE = 40

  def self.available_tesseract_languages
    @_available_tesseract_languages ||= begin
      stdout, = Open3.capture2('tesseract', '--list-langs')
      stdout.lines.drop(1).map(&:strip).reject(&:blank?)
    rescue StandardError
      []
    end
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    extract.text
  end

  def extract
    extracted_pages = extract_text_with_pdf_reader
    extracted_text = join_pages(extracted_pages)
    page_count = extracted_pages.size
    if sufficient_text?(extracted_text, page_count)
      return Result.new(
        text: extracted_text,
        page_count: page_count,
        source: :pdf_reader,
        pages: extracted_pages
      )
    end

    pdftotext_pages = extract_text_with_pdftotext
    pdftotext_text = join_pages(pdftotext_pages)
    pdftotext_page_count = [page_count, pdftotext_pages.size].max
    if sufficient_text?(pdftotext_text, pdftotext_page_count)
      return Result.new(
        text: pdftotext_text,
        page_count: pdftotext_page_count,
        source: :pdftotext,
        pages: pdftotext_pages
      )
    end

    ocr_pages = extract_text_with_ocr
    ocr_text = join_pages(ocr_pages)
    ocr_page_count = [page_count, pdftotext_pages.size, ocr_pages.size].max
    if ocr_text.present?
      Result.new(text: ocr_text, page_count: ocr_page_count, source: :ocr, pages: ocr_pages)
    else
      Result.new(text: extracted_text, page_count: page_count, source: :pdf_reader, pages: extracted_pages)
    end
  end

  private

  def extract_text_with_pdf_reader
    reader = PDF::Reader.new(@file_path)
    reader.pages.to_a.each_with_index.map do |page, index|
      Page.new(page_number: index + 1, text: page.text.to_s)
    end
  rescue StandardError
    []
  end

  def extract_text_with_pdftotext
    return [] unless command_available?('pdftotext')

    output = run_command('pdftotext', '-layout', @file_path, '-')
    output.to_s.split("\f").each_with_index.filter_map do |page_text, index|
      normalized = page_text.to_s.strip
      next if normalized.blank?

      Page.new(page_number: index + 1, text: normalized)
    end
  rescue StandardError
    []
  end

  def sufficient_text?(text, page_count)
    return false if text.blank?
    return true if page_count <= 0

    normalized = text.gsub(/\s+/, ' ').strip
    normalized.length >= (page_count * MIN_TEXT_CHARS_PER_PAGE)
  end

  def extract_text_with_ocr
    return [] unless command_available?('pdftoppm') && command_available?('tesseract')

    Dir.mktmpdir('pdf-ocr') do |dir|
      prefix = File.join(dir, 'page')
      run_command('pdftoppm', '-png', '-r', '200', @file_path, prefix)

      image_paths = Dir.glob("#{prefix}-*.png").sort
      return [] if image_paths.empty?

      image_paths.filter_map.with_index do |image_path, index|
        output = run_command('tesseract', image_path, 'stdout', '-l', ocr_language, '--psm', '6')
        cleaned = output.to_s.strip
        next if cleaned.blank?

        Page.new(page_number: index + 1, text: cleaned)
      end
    end
  rescue StandardError
    []
  end

  def join_pages(pages)
    Array(pages).map(&:text).reject(&:blank?).join("\n\n")
  end

  def run_command(*command)
    stdout, stderr, status = Open3.capture3(*command)
    raise "#{command.first} failed: #{stderr}" unless status.success?

    stdout
  end

  def command_available?(name)
    system('which', name, out: File::NULL, err: File::NULL)
  end

  def ocr_language
    languages = self.class.available_tesseract_languages
    return 'pol+eng' if languages.include?('pol')
    return 'eng' if languages.include?('eng')

    languages.first || 'eng'
  end
end
