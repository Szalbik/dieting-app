# frozen_string_literal: true

class LineParserFactory
  def self.parser_for(line)
    # if found '-' example 'string-string' in sentence "Jogurt pitny Twist, brzoskwinia-mango -1szt. (380g) np. Bakoma" then do not count '-'
    return unless line.include?('-')

    case line.count('-')
    when 1
      OneDashLineParser.new
    when 2
      return OneDashLineParser.new if line.strip =~ /[a-z]+-[a-z]+/

      TwoDashLineParser.new
    when 3
      ThreeDashLineParser.new
    else
      raise "No parser for line: #{line}"
    end
  end
end
