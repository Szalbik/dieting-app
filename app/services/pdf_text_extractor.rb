# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'pdf-reader'

class PdfTextExtractor
  Result = Struct.new(:text, :page_count, :source, keyword_init: true)

  MIN_TEXT_CHARS_PER_PAGE = 40

  def initialize(file_path)
    @file_path = file_path
  end

  def call
    extract.text
  end

  def extract
    extracted_text, page_count = extract_text_with_pdf_reader
    return Result.new(text: extracted_text, page_count: page_count, source: :pdf_reader) if sufficient_text?(extracted_text, page_count)

    pdftotext_text = extract_text_with_pdftotext
    return Result.new(text: pdftotext_text, page_count: page_count, source: :pdftotext) if sufficient_text?(pdftotext_text, page_count)

    ocr_text = extract_text_with_ocr
    if ocr_text.present?
      Result.new(text: ocr_text, page_count: page_count, source: :ocr)
    else
      Result.new(text: extracted_text, page_count: page_count, source: :pdf_reader)
    end
  end

  private

  def extract_text_with_pdf_reader
    reader = PDF::Reader.new(@file_path)
    pages = reader.pages.to_a
    text = pages.map(&:text).compact.join("\n")
    [text, pages.size]
  rescue StandardError
    ['', 0]
  end

  def extract_text_with_pdftotext
    return '' unless command_available?('pdftotext')

    output = run_command('pdftotext', '-layout', @file_path, '-')
    output.to_s.tr("\f", "\n").strip
  rescue StandardError
    ''
  end

  def sufficient_text?(text, page_count)
    return false if text.blank?
    return true if page_count <= 0

    normalized = text.gsub(/\s+/, ' ').strip
    normalized.length >= (page_count * MIN_TEXT_CHARS_PER_PAGE)
  end

  def extract_text_with_ocr
    return '' unless command_available?('pdftoppm') && command_available?('tesseract')

    Dir.mktmpdir('pdf-ocr') do |dir|
      prefix = File.join(dir, 'page')
      run_command('pdftoppm', '-png', '-r', '200', @file_path, prefix)

      image_paths = Dir.glob("#{prefix}-*.png").sort
      return '' if image_paths.empty?

      image_paths.filter_map do |image_path|
        output = run_command('tesseract', image_path, 'stdout', '-l', ocr_language, '--psm', '6')
        cleaned = output.to_s.strip
        cleaned.presence
      end.join("\n\n")
    end
  rescue StandardError
    ''
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

  def self.available_tesseract_languages
    @available_tesseract_languages ||= begin
      stdout, = Open3.capture2('tesseract', '--list-langs')
      stdout.lines.drop(1).map(&:strip).reject(&:blank?)
    rescue StandardError
      []
    end
  end
end
