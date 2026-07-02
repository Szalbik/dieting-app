# frozen_string_literal: true

class CategorizeProductsJob < ApplicationJob
  queue_as :default

  def perform
    Product.uncategorized.find_each do |product|
      product.categorize_if_needed
    end

    # Batched last-resort AI sweep for whatever local classification left uncategorized.
    Chat::ProductCategorizerService.new(products: Product.uncategorized).call
  end
end
