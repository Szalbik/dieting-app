# frozen_string_literal: true

class OneDashLineParser < LineParser
  def parse(line)
    # Remove the leading dash and whitespace.
    text = line.sub(/\A-\s*/, '').strip
    measurements = []

    # First, look for a measurement preceded by a dash at the end.
    # This matches a dash followed by digits and additional text.
    if text =~ /\s*-\s*(?<measurement>\d.*)$/
      measurement_str = Regexp.last_match(:measurement).strip
      measurements += include_number?(measurement_str) ? split_measurement(measurement_str) : []
      text = text.sub(/\s*-\s*\d.*$/, '').strip
    end

    # Next, look for a measurement in parentheses at the very end.
    if text =~ /\s*\((?<measurement>[^)]+)\)\s*\z/
      measurement_str = Regexp.last_match(:measurement).strip
      measurements += include_number?(measurement_str) ? split_measurement(measurement_str) : []
      text = text.sub(/\s*\([^)]+\)\s*\z/, '').strip
    end

    [text, measurements.empty? ? nil : measurements]
  end
end
