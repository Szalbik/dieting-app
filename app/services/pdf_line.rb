# frozen_string_literal: true

class PdfLine
  attr_reader :line

  def initialize(line)
    @line = line
  end

  def to_s
    line.text
  end

  def to_str
    to_s
  end

  def ==(other)
    to_s == other.to_s
  end

  def include?(other)
    to_s.include?(other.to_s)
  end

  def count(other)
    to_s.count(other.to_s)
  end

  def strip
    to_s.strip
  end

  def split(other)
    to_s.split(other.to_s)
  end
end
