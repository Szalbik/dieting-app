class CategorizeProductsJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)
    diet.categorize_products!
  end
end
