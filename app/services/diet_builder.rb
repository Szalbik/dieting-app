# frozen_string_literal: true

class DietBuilder
  attr_reader :ingredients

  def initialize(diet)
    @diet = diet
    @current_set = nil
    @line_processing_value = false
  end

  def process_page(page)
    lines = page.text.split("\n")

    lines.each do |line|
      next unless should_process_line?(line)

      process_line(line)
    end
  end

  def should_process_line?(line)
    return false if set_current_set(line)

    @line_processing_value = true if line.strip =~ /^1\) Śniadanie$/
    @line_processing_value = true if line.strip =~ /^2\) Przekąska$/
    @line_processing_value = true if line.strip =~ /^3\) Obiad$/
    @line_processing_value = true if line.strip =~ /^4\) Kolacja$/
    return false unless @line_processing_value

    return false if line.strip.blank?
    return false if line.strip =~ /^\d+\.\s/
    return false if line.strip =~ /\d+\s-\s\d+/
    return false if line.strip =~ /\d+-\d+/
    return false unless line.strip.include?('-')
    return false if line.strip.include?('tel.:')

    valid_current_set?
  end

  def set_current_set(line)
    recipe_set_regex = /^Zestaw (\d+)/
    recipe_set_match = line.strip.match(recipe_set_regex)

    if recipe_set_match
      set_name = "Zestaw #{recipe_set_match[1]}"
      @current_set = @diet.diet_sets.detect { |diet_set| diet_set.name == set_name } ||
                     @diet.diet_sets.build(name: set_name)
    end
  end

  def valid_current_set?
    current_set.present?
  end

  def process_line(line)
    parser = LineParserFactory.parser_for(line)
    ingredient_name, ingredient_measurements = parser.parse(line)

    return unless ingredient_name.present?

    ingredient_object = Ingredient.new(ingredient_name)
    if ingredient_measurements
      ingredient_measurements.uniq.each do |measure|
        measurement = Measurement.new(amount: measure[0].to_f, unit: measure[1])
        ingredient_object.add_measurement(measurement)
      end
    end

    # Build product
    product = current_set.products.build(name: ingredient_object.name)

    # Build ingredient measures
    ingredient_object.measurements.each do |measurement|
      product.ingredient_measures.build(amount: measurement.amount, unit: measurement.unit)
    end
  end

  def save_ingredients
    diet.save
  end

  private

  attr_reader :diet, :current_set
end
