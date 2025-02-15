# frozen_string_literal: true

class DietBuilderJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)
    diet.parse_pdf_content!
    ClassifyProductsJob.perform_later(diet.id)
  end
end
