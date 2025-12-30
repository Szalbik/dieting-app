# frozen_string_literal: true

class DietBuilderJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)

    # Use the new schema-validated parser with OpenAI
    diet.parse_pdf_content_with_chat!

    # Populate diet sets, meals, and products from the parsed JSON
    # ClassifyProductsJob will be called automatically after population
    PopulateDietFromJsonJob.perform_later(diet.id) if diet.parsed_json.present?
  end
end
