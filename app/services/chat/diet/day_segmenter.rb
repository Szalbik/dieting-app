# frozen_string_literal: true

# Splits extracted pages into one chunk per diet day, tracking which source
# pages contributed to each chunk (needed so the OCR-image fallback can
# attach only the relevant page images to a given day's OpenAI call).
# Same page-walking approach and day-header regex as the old per-meal
# Segmenter, now stopping at day granularity since ParsingPipeline sends
# one full day per request instead of one call per meal-stage.
class Chat::Diet::DaySegmenter
  DAY_HEADER_REGEX = /\b(?:zestaw|dzie(?:ń|n)|day)\s+(\d+)\b/i

  Chunk = Struct.new(:day, :markdown, :page_numbers, keyword_init: true)

  # headings: optional { "heading line" => day_number } from the model, used
  # when the document has no "Dzień/Zestaw N" markers the regex can find.
  def initialize(pages, headings: nil)
    @pages = Array(pages)
    # Longest key first so "wariant ab" isn't shadowed by "wariant a".
    @headings = headings&.transform_keys { |heading| normalize(heading) }
      &.reject { |key, _| key.blank? }
      &.sort_by { |key, _| -key.size }&.to_h
    @fallback = false
  end

  # True when no day marker was found and the whole document became day 1.
  def fallback?
    @fallback
  end

  def call
    chunks = []
    current_day = nil
    lines = []
    page_numbers = []

    @pages.each do |page|
      page.text.to_s.each_line do |line|
        day_number = detect_day_number(line)
        if day_number
          chunks << build_chunk(current_day, lines, page_numbers) if current_day
          current_day = day_number
          lines = [line]
          page_numbers = [page.page_number]
          next
        end

        next unless current_day

        lines << line
        page_numbers << page.page_number
      end
    end

    chunks << build_chunk(current_day, lines, page_numbers) if current_day

    if chunks.empty?
      @fallback = true
      return [whole_document_as_single_day]
    end

    chunks
  end

  private

  def whole_document_as_single_day
    Chunk.new(
      day: 1,
      markdown: @pages.map(&:text).reject(&:blank?).join("\n\n").strip,
      page_numbers: @pages.map(&:page_number)
    )
  end

  def build_chunk(day, lines, page_numbers)
    Chunk.new(day: day, markdown: lines.join.strip, page_numbers: page_numbers.uniq.sort)
  end

  def detect_day_number(line)
    # A printed heading may carry a suffix the model dropped ("Poniedziałek –
    # 1800 kcal"); match on the leading text, but only at a word boundary so
    # "dzień 1" never claims "dzień 10".
    if @headings
      normalized = normalize(line)
      return @headings.find { |heading, _day| normalized == heading || normalized.start_with?("#{heading} ") }&.last
    end

    # Strip markdown emphasis (**bold**, _italic_) before matching: a day
    # heading like "**_Zestaw 2_**" has an underscore directly adjacent to
    # both "Zestaw" and "2". Underscore counts as a \w character, so it
    # silently defeats \b word-boundary detection on both sides of the regex.
    normalized_line = line.gsub(/[*_]/, '')
    normalized_line.match(DAY_HEADER_REGEX)&.captures&.first&.to_i
  end

  # Markdown decoration and case differ between the model's copy of a heading
  # and the extracted line; compare the bare text.
  def normalize(text)
    text.to_s.gsub(/[*_#|]/, ' ').squish.downcase
  end
end
