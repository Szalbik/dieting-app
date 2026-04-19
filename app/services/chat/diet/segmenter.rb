# frozen_string_literal: true

class Chat::Diet::Segmenter
  DAY_HEADER_REGEX = /\b(?:zestaw|dzie(?:ń|n)|day)\s+(\d+)\b/i
  MEAL_HEADER_REGEX = /^\s*(\d+)\)\s+(.+?)\s*$/.freeze

  def initialize(pages)
    @pages = Array(pages)
  end

  def call
    segments = []
    current_day = nil
    current_segment = nil

    @pages.each do |page|
      page_text = page.text.to_s
      lines = page_text.lines

      current_day ||= detect_day_number(page_text)

      lines.each do |line|
        if (day_number = detect_day_number(line))
          current_day = day_number
          next
        end

        meal_match = line.match(MEAL_HEADER_REGEX)
        if meal_match
          segments << build_segment(current_segment) if current_segment
          current_day ||= infer_day_number(segments)
          meal_position = meal_match[1].to_i
          meal_label = meal_match[2].to_s.strip
          current_segment = start_segment(current_day, meal_position, meal_label, page.page_number)
          current_segment[:lines] << line.strip
          next
        end

        next unless current_segment

        current_segment[:lines] << line.rstrip
        current_segment[:page_numbers] << page.page_number
      end
    end

    segments << build_segment(current_segment) if current_segment
    segments
  end

  private

  def start_segment(day_number, meal_position, meal_label, page_number)
    {
      id: "day-#{day_number}-meal-#{meal_position}",
      day_number: day_number,
      meal_position: meal_position,
      meal_label: meal_label,
      lines: [],
      page_numbers: [page_number],
    }
  end

  def build_segment(segment_hash)
    Chat::Diet::ParsingSegment.new(
      id: segment_hash[:id],
      day_number: segment_hash[:day_number],
      meal_position: segment_hash[:meal_position],
      meal_label: segment_hash[:meal_label],
      text: normalize_segment_text(segment_hash[:lines]),
      page_numbers: segment_hash[:page_numbers]
    )
  end

  def normalize_segment_text(lines)
    Array(lines)
      .map(&:to_s)
      .join("\n")
      .gsub(/\n{3,}/, "\n\n")
      .strip
  end

  def detect_day_number(text)
    text.to_s.match(DAY_HEADER_REGEX)&.captures&.first&.to_i
  end

  def infer_day_number(existing_segments)
    existing_segments.last&.day_number.to_i + 1
  end
end
