# frozen_string_literal: true

class DietBuilder
  def initialize(diet)
    @diet = diet
    @page_parser = DietPageParser.new(@diet)
  end

  # Processes a PDF::Reader::Page (or any object that responds to #text)
  def process_page(page)
    @page_parser.process(page)
  end

  # When finished, persist the diet (or do additional processing as needed)
  def save_ingredients
    @diet.save
  end
end
