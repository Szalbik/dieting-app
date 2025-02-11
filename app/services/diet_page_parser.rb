# frozen_string_literal: true

class DietPageParser
  def initialize(diet)
    @diet = diet
    @current_set = nil           # current DietSet
    @current_meal = nil          # current Meal
    @current_section = :ingredients  # or :instructions
    @current_instructions = String.new   # accumulator for instructions text
  end

  def process(page)
    lines = page.text.split("\n")
    lines.each { |line| process_line(line) }
    flush_instructions if @current_section == :instructions && @current_meal.present? && @current_instructions.present?
  end

  private

  def process_line(line)
    normalized = line.strip
    return if normalized.empty?

    # --- Skip meta or schedule lines ---
    return if normalized.match?(/^(tel\.|Poradnia Dietetyczna|dietetyk\.)/i)
    return if normalized.match?(/^\d{1,2}:\d{2}/)
    if @current_set.nil? && normalized.match?(/^(Dieta dla|Godziny spożywania posiłków)/i)
      return
    end

    # --- Diet Set header: e.g. "Zestaw 1" ---
    if diet_set_header?(normalized)
      process_diet_set_header(normalized)
      return
    end

    # --- Meal header: e.g. "1) Śniadanie", "2) Przekąska", etc. ---
    if meal_header?(normalized)
      flush_instructions if @current_section == :instructions && @current_instructions.strip.present?
      process_meal_header(normalized)
      return
    end

    # --- Instructions header: e.g. "Sposób przygotowania:" ---
    if normalized =~ /^Sposób (wykonania|przygotowania):/
      @current_section = :instructions
      @current_instructions = String.new
      return
    end

    # --- Process line based on current section ---
    if @current_section == :instructions
      @current_instructions << normalized + "\n"
    else
      process_ingredient_line(normalized)
    end
  end

  def flush_instructions
    if @current_meal && @current_instructions.strip.present?
      @current_meal.instructions = @current_instructions.strip
      @current_instructions = String.new
      @current_section = :ingredients
    end
  end

  def diet_set_header?(line)
    line.match?(/^Zestaw \d+/)
  end

  def process_diet_set_header(line)
    if line =~ /^Zestaw (\d+)/
      set_name = "Zestaw #{$1}"
      @current_set = @diet.diet_sets.find_by(name: set_name) ||
                     @diet.diet_sets.build(name: set_name)
      # Reset current meal and instructions for new set.
      @current_meal = nil
      @current_section = :ingredients
      @current_instructions = String.new
    end
  end

  def meal_header?(line)
    line.match?(/^\d+\)\s*(Śniadanie|Przekąska|Obiad|Kolacja)(\s+[IVX]+)?$/)
  end

  def process_meal_header(line)
    # Create a new Meal within the current DietSet.
    @current_meal = @current_set.meals.build(name: line)
    @current_section = :ingredients
  end

  def process_ingredient_line(line)
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

  def create_product(ingredient_name, measurements)
    return unless @current_meal && ingredient_name.present?

    product = @current_meal.products.build(name: ingredient_name)
    if measurements
      measurements.each do |amount, unit|
        product.ingredient_measures.build(amount: amount.to_f, unit: unit)
      end
    end
  end
end
