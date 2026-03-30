# frozen_string_literal: true

class LineParser
  def parse(line)
    raise NotImplementedError, 'Subclasses must implement #parse'
  end

  def split_measurement(measurement)
    units = %w[g szt kromka kromki łyżeczka łyżeczki łyżka szkl ml ząbek ząbki gałązka gałązki garść garście plastry]
    # Longer units first so e.g. "gałązki" is not parsed as "g" + leftover letters.
    units_regex = Regexp.union(units.sort_by { |u| -u.length })
    matches = measurement.scan(/(\d+(?:\/\d+)?)(?:\s*)(#{units_regex})/)
    matches.map do |quantity, unit|
      if quantity.include?('/')
        num, denom = quantity.split('/').map(&:to_f)
        [num / denom, unit]
      else
        [quantity.to_f, unit]
      end
    end
  end

  def include_number?(line)
    line =~ /\d/
  end
end
