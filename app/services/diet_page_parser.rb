# frozen_string_literal: true

class DietPageParser
  def initialize(diet)
    @diet = diet
    @current_set = nil
    @current_section = :ingredients   # Can be :ingredients or :preparation
    @prep_parser = nil
  end

  # Expects a page object with a `#text` method.
  def process(page)
    lines = page.text.split("\n")
    lines.each { |line| process_line(line) }
  end

  private

  def process_line(line)
    normalized = line.strip
    return if normalized.empty?

    # Skip meta lines regardless of whether a diet set is active
    return if normalized.match?(/^(tel\.|Poradnia Dietetyczna|dietetyk\.)/i)

    # Skip lines that look like time schedules, e.g. "08:00 - 09:00 ..."
    return if normalized.match?(/^\d{1,2}:\d{2}/)

    # ---- Guard: Skip meta/header lines until a diet set is active ----
    if @current_set.nil? && normalized.match?(/^(Dieta dla|Godziny spożywania posiłków|Poradnia Dietetyczna|tel\.:|dietetyk\.)/)
      return
    end

    # ---- New Diet Set header (e.g. "Zestaw 1") ----
    if diet_set_header?(normalized)
      process_diet_set_header(normalized)
      return
    end

    # ---- Meal headers (e.g. "1) Śniadanie", "2) Przekąska", etc.) ----
    if meal_header?(normalized)
      # Exit any active preparation mode
      @current_section = :ingredients
      @prep_parser = nil
      # (Optionally, you can log the meal header.)
    end

    # ---- Preparation section header ----
    if normalized.downcase.include?('sposób wykonania')
      @current_section = :preparation
      @prep_parser = PreparationSectionParser.new(@current_set)
      return
    end

    # ---- Delegate processing based on section ----
    if @current_section == :preparation
      # Use a heuristic: if the line contains a dash and a digit, treat it as a product.
      if normalized =~ /-.*\d/
        @prep_parser.process(normalized)
      end
    else
      process_ingredient_line(normalized)
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
      # Reset section to ingredients
      @current_section = :ingredients
      @prep_parser = nil
    end
  end

  def meal_header?(line)
    # Example meal headers: "1) Śniadanie", "2) Przekąska", "3) Obiad", "4) Kolacja"
    line.match?(/^(1\) Śniadanie|2\) Przekąska|3\) Obiad|4\) Kolacja)$/)
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
    return unless @current_set && ingredient_name.present?

    product = @current_set.products.build(name: ingredient_name)
    if measurements
      measurements.each do |amount, unit|
        product.ingredient_measures.build(amount: amount, unit: unit)
      end
    end
  end
end
