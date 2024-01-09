class DietBuilderJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)
    diet.parse_pdf_content!
    # CategorizeProductsJob.perform_later(diet.id)
    ClassifyProductsJob.perform_later(diet.id)
  end
end
