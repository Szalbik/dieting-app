# frozen_string_literal: true

class Chat::Diet::ParsingSegment
  attr_reader :id, :day_number, :meal_position, :meal_label, :page_numbers

  def initialize(id:, day_number:, meal_position:, meal_label:, text:, page_numbers:)
    @id = id
    @day_number = day_number
    @meal_position = meal_position
    @meal_label = meal_label.to_s.strip
    @text = text.to_s
    @page_numbers = Array(page_numbers).map(&:to_i).uniq.sort
  end

  def text
    @text.strip
  end

  def low_quality_text?
    text.gsub(/\s+/, ' ').length < 140
  end
end
