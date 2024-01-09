# frozen_string_literal: true

class OneDashLineParser < LineParser
  def parse(line)
    parts = " #{line}".split(' -')

    if line.start_with?('-')
      ingredient = parts[1].slice(/[\p{L}\s]+/).strip
      measurement = parts[1].sub(ingredient, '').strip

      # checks if line contains number
      ingredient = parts[1].strip unless include_number?(line)
    else
      ingredient = parts[0].strip
      measurement = parts[1].strip
    end

    measurements = (split_measurement(measurement) if include_number?(measurement))

    [ingredient, measurements]
  end

  def include_number?(line)
    line =~ /\d/
  end
end
