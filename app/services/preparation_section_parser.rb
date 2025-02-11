# frozen_string_literal: true

class PreparationSectionParser
  def initialize(diet_set)
    @diet_set = diet_set
  end

  def process(line)
    parser = LineParserFactory.parser_for(line)
    return unless parser

    result = parser.parse(line)
    if result.is_a?(Array) && result.first.is_a?(Array)
      result.each { |ingredient_name, measurements| create_product(ingredient_name, measurements) }
    else
      ingredient_name, measurements = result
      create_product(ingredient_name, measurements)
    end
  end

  private

  def create_product(ingredient_name, measurements)
    return if ingredient_name.blank?

    product = @diet_set.products.build(name: ingredient_name)
    if measurements
      measurements.each do |amount, unit|
        product.ingredient_measures.build(amount: amount, unit: unit)
      end
    end
  end
end
