# frozen_string_literal: true

class DietBuilder
  def initialize(diet)
    @diet = diet
    @page_parser = DietPageParser.new(@diet)
  end

  # Process a PDF page using the refactored parser.
  def process_page(page)
    @page_parser.process(page)
  end

  # Persist the diet (or perform additional processing).
  def save_ingredients
    @diet.save
  end
end
