# frozen_string_literal: true

class LineParser
  def parse(line)
    raise NotImplementedError, 'Subclasses must define #parse'
  end

  def split_measurement(measurement)
    units = %w[g szt kromka kromki łyżeczka łyżeczki łyżka szkl ml ząbek ząbki gałązka gałązki garść garście plastry]
    measurements = []

    units.each do |unit|
      next unless measurement.include?(unit)

      measurement.split(' ').each do |item|
        next unless item.include?(unit)

        # remove parentheses and unit
        quantity = item.gsub('(', '').gsub(')', '').split(unit).first&.strip

        # if quantity is nil, it means that there is a space between quantity and unit
        # in this case we should take quantity from previous item
        if quantity.nil?
          item_index = measurement.split(' ').find_index(item)
          quantity = measurement.split(' ')[item_index - 1].strip
        end

        # do not store float
        if quantity&.include?('/')
          next
          # quantity = quantity.split('/').first.to_f / quantity.split('/').last.to_f
        end

        # check if quantity is a number or float
        measurements << [quantity.to_i, unit] if include_number?(quantity)
      end
    end
    measurements
  end

  def include_number?(line)
    line =~ /\d/
  end
end
