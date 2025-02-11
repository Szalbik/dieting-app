# frozen_string_literal: true

class LineParserFactory
  def self.parser_for(line)
    normalized = line.strip
    # Check for spice lines: they start with a dash and optionally "przyprawy:" and contain commas.
    if normalized =~ /^-\s*(przyprawy:)?/i && normalized.include?(',')
      return SpiceLineParser.new
    end

    return nil unless normalized.include?('-')

    case normalized.count('-')
    when 1
      OneDashLineParser.new
    when 2
      if normalized =~ /[a-z]+-[a-z]+/
        OneDashLineParser.new
      else
        TwoDashLineParser.new
      end
    when 3
      ThreeDashLineParser.new
    else
      raise "No parser available for line: #{line}"
    end
  end
end
