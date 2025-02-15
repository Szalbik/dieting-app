# frozen_string_literal: true

# app/services/two_dash_line_parser.rb
class TwoDashLineParser < LineParser
  def parse(line)
    # We expect lines with two or more dashes and a leading dash.
    if line.start_with?('-') && line.count('-') >= 2
      regex = /^-\s*(?<prod>.+?)\s*-\s*(?<meas>\d+(?:\/\d+)?(?:\s+\S+)+)(?:\s+(?<extra>.+))?$/
      match = regex.match(line)
      if match
        main_product = match[:prod].strip
        measurement_str = match[:meas].strip
        extra = match[:extra]&.strip
        # Append any extra text (which might include "lub" and more) to the product name.
        main_product = "#{main_product} #{extra}".strip if extra.present?
        measurements = []

        # If the measurement string includes a parenthesis, split it into two parts.
        if measurement_str.include?('(')
          if measurement_str =~ /^(?<first>.+?)\s*\((?<second>[^)]+)\)\s*$/
            first_part = Regexp.last_match(:first).strip
            second_part = Regexp.last_match(:second).strip
            measurements += include_number?(first_part) ? split_measurement(first_part) : []
            measurements += include_number?(second_part) ? split_measurement(second_part) : []
          else
            # Fallback if regex fails—treat entire string as one measurement.
            measurements = split_measurement(measurement_str)
          end
        else
          measurements = split_measurement(measurement_str)
        end

        return [main_product, measurements]
      end
    end

    # Fallback: if our regex doesn't match, then use a simple dash-splitting
    parts = line.split('-')
    ingredient = parts[1]&.strip || ''
    measurement = parts[2]&.strip || ''
    measurements = include_number?(measurement) ? split_measurement(measurement) : nil
    [ingredient, measurements]
  end
end
