# frozen_string_literal: true

# A class to represent a measurement, each ingredient can have multiple measurements
class Measurement
  attr_reader :amount, :unit

  def initialize(amount: 0, unit: '')
    @amount = amount
    @unit = unit
  end

  def to_s
    "#{amount} #{unit}"
  end
end
