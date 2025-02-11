# frozen_string_literal: true

class ThreeDashLineParser < LineParser
  def parse(line)
    line = line.split('lub').first.strip if line.include?('lub')
    TwoDashLineParser.new.parse(line)
  end
end
