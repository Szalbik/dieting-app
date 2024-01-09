class ClassifyProductsJob < ApplicationJob
  queue_as :default

  def perform(diet_id)
    diet = Diet.find(diet_id)
    diet.classify_products!
  end
end
