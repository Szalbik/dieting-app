# frozen_string_literal: true

class TwoDashLineParser < LineParser
  INGREDIENT_REGEXP = %r{(\d+(?:/\d+)?)\s*([A-Za-z]+)}

  def parse(line)
    line = line.split('lub').first.strip if line.include?('lub')

    if line.count('-') == 1
      OneDashLineParser.new.parse(line)
    else
      parts = line.split('-')
      ingredient = parts[1].strip
      measurement = parts[2].strip

      measurements = (split_measurement(measurement) if include_number?(measurement))

      [ingredient, measurements]
    end
  end

  def include_number?(line)
    line =~ /\d/
  end
end
