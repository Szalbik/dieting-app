# frozen_string_literal: true

class SpiceLineParser < LineParser
  # Parses lines such as:
  #   "-przyprawy: oregano, tymianek, sól, pieprz, słodka mielona papryka, płatki chili"
  #   "-sól, pieprz"
  def parse(line)
    cleaned = line.strip.sub(/\A-\s*/, '').sub(/\Aprzyprawy:\s*/i, '')
    # Split by commas (assuming commas are not used inside parentheses).
    spice_items = cleaned.split(/\s*,\s*/).reject(&:empty?)
    spice_items.map do |item|
      if item =~ /^(.*?)(\d+(?:\/\d+)?\s*\S+.*)$/
        ingredient = Regexp.last_match(1).strip
        measurement_str = Regexp.last_match(2).strip
        measurements = split_measurement(measurement_str)
        [ingredient, measurements]
      else
        [item.strip, nil]
      end
    end
  end
end
