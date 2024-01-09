# frozen_string_literal: true

# A class to represent an ingredient, each ingredient can have multiple measurements
class Ingredient
  attr_reader :name, :measurements

  def initialize(name, measurements = [])
    @name = name
    @measurements = measurements
  end

  def to_s
    "#{name} - #{measurements.each(&:to_s).join(', ')}"
  end

  def add_measurement(measurement)
    @measurements << measurement
  end
end
