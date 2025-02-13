# frozen_string_literal: true

class OneDashLineParser < LineParser
  def parse(line)
    # Remove the leading dash and whitespace.
    text = line.sub(/\A-\s*/, '').strip

    # Case 1: Look for measurement info enclosed in parentheses at the end.
    if text =~ /^(?<ingredient>.+?)\s*\((?<measurement>[^)]+)\)\s*\z/
      ingredient = Regexp.last_match(:ingredient).strip
      measurement_str = Regexp.last_match(:measurement).strip
      measurements = include_number?(measurement_str) ? split_measurement(measurement_str) : nil
      [ingredient, measurements]
    # Case 2: Otherwise, try splitting at the first space before a digit.
    elsif text =~ /^(?<ingredient>.+?)\s+(?<measurement>\d.*)$/
      ingredient = Regexp.last_match(:ingredient).strip
      measurement_str = Regexp.last_match(:measurement).strip
      measurements = include_number?(measurement_str) ? split_measurement(measurement_str) : nil
      [ingredient, measurements]
    else
      [text, nil]
    end
  end
end
