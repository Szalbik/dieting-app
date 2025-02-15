# frozen_string_literal: true

class DietPageParser
  INGREDIENT_REGEX = /
    ^-?\s*                              # Optional leading dash and spaces
    (?<name>[\p{L}\s,]+?)                # Ingredient name: letters, spaces, commas
    (?:\s*-\s*(?<amount>\d+(?:[\/.,]\d+)?)(?<unit>[^\s]+))?   # Optional: " - amountunit"
    (?:\s*\((?<volume>[^)]+)\))?         # Optional volume in parentheses
    (?:\s*np\.\s*(?<note>[\p{L}\s]+))?    # Optional note (e.g., "np. Bakoma")
  $/xu

  META_LINES_COUNT = 4  # Change this value if necessary

  def initialize(diet)
    @diet = diet
    @current_set = nil       # Current DietSet
    @current_meal = nil      # Current Meal
    @current_section = :ingredients   # Can be :ingredients or :instructions
    @current_instructions = String.new  # Mutable string for instructions
    @expecting_meal_name = false
    @current_meal_header = nil  # Stores meal header text (e.g., "1) Śniadanie")
  end

  # Process a PDF page.
  # Splits the page into lines, then removes the last META_LINES_COUNT lines (assumed meta lines),
  # then normalizes and processes the remaining lines.
  def process(page)
    raw_content = page.text.split("\n")
    raw_content = raw_content.size >= META_LINES_COUNT ? raw_content[0...-META_LINES_COUNT] : raw_content

    normalized_content = raw_content.map(&:strip).reject(&:empty?)
    normalized_content.each { |line| process_line(line) }
    flush_instructions if @current_section == :instructions && @current_instructions.strip.present?
  end

  private

  def process_line(line)
    # Skip common meta/schedule lines.
    return if line.match?(/^(tel\.|Poradnia Dietetyczna|dietetyk\.)/i)
    return if line.match?(/^\d{1,2}:\d{2}/)
    return if @current_set.nil? && line.match?(/^(Dieta dla|Godziny spożywania posiłków)/i)

    # Diet Set header (e.g., "Zestaw 1")
    if diet_set_header?(line)
      process_diet_set_header(line)
      return
    end

    # Meal header (e.g., "1) Śniadanie", "2) Przekąska I", etc.)
    if meal_header?(line)
      flush_instructions if @current_section == :instructions && @current_instructions.strip.present?
      @current_meal_header = line
      @expecting_meal_name = true
      return
    end

    # When expecting a meal name and the line does not start with a dash,
    # treat it as the meal name (and possibly as an ingredient line).
    if @expecting_meal_name && !line.start_with?('-')
      meal_title = "#{@current_meal_header}: #{clean_meal_name(line)}".strip
      @current_meal = @current_set.meals.build(name: meal_title)
      @current_section = :ingredients
      @expecting_meal_name = false

      # If the meal name line includes measurement info, process it as an ingredient.
      process_ingredient_line("-#{line}") if contains_measurement_info?(line)
      @current_meal_header = nil
      return
    end

    # Switch to instructions section when an instructions header is found.
    if line =~ /^Sposób\b.*:/
      @current_section = :instructions
      @current_instructions = String.new  # Reset mutable string
      return
    end

    # Process the line based on the current section.
    if @current_section == :instructions
      if is_ingredient?(line)
        process_ingredient_line(line)
      else
        @current_instructions << line + "\n"
      end
    else
      process_ingredient_line(line)
    end
  end

  def flush_instructions
    if @current_meal && @current_instructions.strip.present?
      cleaned_instructions = filter_ingredients_from_instructions(@current_instructions)
      @current_meal.instructions = cleaned_instructions.strip
      @current_instructions = String.new  # Reset mutable string
      @current_section = :ingredients
    end
  end

  # In the instructions block, simply skip lines that match the ingredient pattern
  # to avoid processing them twice.
  def filter_ingredients_from_instructions(instructions)
    kept_lines = []
    instructions.split("\n").each { |line| kept_lines << line unless is_ingredient?(line) }
    kept_lines.join("\n")
  end

  def diet_set_header?(line)
    line.match?(/^Zestaw \d+/)
  end

  def process_diet_set_header(line)
    if line =~ /^Zestaw (\d+)/
      set_name = "Zestaw #{$1}"
      @current_set = @diet.diet_sets.find_by(name: set_name) || @diet.diet_sets.build(name: set_name)
      # Reset state for the new set.
      @current_meal = nil
      @current_section = :ingredients
      @current_instructions = String.new
      @expecting_meal_name = false
      @current_meal_header = nil
    end
  end

  def meal_header?(line)
    line.match?(/^\d+\)\s*(Śniadanie|Przekąska|Obiad|Kolacja)(\s+[IVX]+)?$/)
  end

  def clean_meal_name(name)
    name.gsub(/\s*-\s*\d+(?:[\/.,]\d+)?\s*\S+(?:\s*\([^)]*\))?/, '').strip
  end

  def contains_measurement_info?(text)
    !!(text =~ /^(?<ingredient>.+?)\s*\((?<measurement>[^)]+)\)\s*\z/ || text =~ /-\s*\d/)
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
      measurements.each { |amount, unit| product.ingredient_measures.build(amount: amount.to_f, unit: unit) }
    end
  end

  # Updated is_ingredient? method: if the line starts with a number (1 to 99) and a dot-space,
  # it's considered an instruction, not an ingredient.
  def is_ingredient?(line)
    stripped = line.strip
    return false if stripped =~ /\d+\s*-\s*\d+/
    return false if stripped =~ /^(?:[1-9]\d?\.\s+)/

    !!stripped.match(INGREDIENT_REGEX)
  end
end
