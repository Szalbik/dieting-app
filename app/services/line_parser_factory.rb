# frozen_string_literal: true

class LineParserFactory
  def self.parser_for(line)
    normalized = line.strip

    # Use SpiceLineParser only if the line explicitly starts with "-przyprawy:" (case-insensitive)
    # if normalized =~ /^-\s*przyprawy:/i
    #   return SpiceLineParser.new
    # end

    # Otherwise, if the line contains a dash, use OneDashLineParser.
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
