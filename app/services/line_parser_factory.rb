# frozen_string_literal: true

class LineParserFactory
  def self.parser_for(line)
    case line.count('-')
    when 1
      OneDashLineParser.new
    when 2
      TwoDashLineParser.new
    when 3
      ThreeDashLineParser.new
    else
      raise "No parser for line: #{line}"
    end
  end
end
