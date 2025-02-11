# frozen_string_literal: true

class TwoDashLineParser < LineParser
  def parse(line)
    line = line.split('lub').first.strip if line.include?('lub')
    if line.count('-') == 1
      OneDashLineParser.new.parse(line)
    else
      parts = line.split('-')
      ingredient = parts[1].strip
      measurement = parts[2].strip
      measurements = include_number?(measurement) ? split_measurement(measurement) : nil
      [ingredient, measurements]
    end
  end
end
