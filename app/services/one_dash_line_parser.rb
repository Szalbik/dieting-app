# frozen_string_literal: true

class OneDashLineParser < LineParser
  def parse(line)
    parts = " #{line}".split(' -')
    # If we don't have at least two parts, return the entire line as the ingredient.
    return [line.strip, nil] if parts.size < 2

    if line.start_with?('-')
      # Use a safe navigation in case parts[1] is nil (shouldn't happen due to the guard above)
      ingredient = parts[1]&.slice(/[\p{L}\s]+/)&.strip || parts[1].to_s.strip
      measurement = parts[1].sub(ingredient, '').strip
      # Fallback: if no digits are found, use the whole parts[1] as ingredient.
      ingredient = parts[1].strip unless include_number?(line)
    else
      ingredient = parts[0].strip
      measurement = parts[1].strip
    end

    measurements = include_number?(measurement) ? split_measurement(measurement) : nil
    [ingredient, measurements]
  end
end
