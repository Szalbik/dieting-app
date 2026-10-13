# frozen_string_literal: true

class CategorizeProductsJob < ApplicationJob
  queue_as :default

  def perform
    # Orphans of deleted diets are never sent to the AI — DataRetentionJob deletes them.
    products = Product.uncategorized.where.not(id: Product.orphaned.select(:id))
    products.find_each do |product|
      product.categorize_if_needed
    end

    # Batched last-resort AI sweep for whatever local classification left uncategorized.
    Chat::ProductCategorizerService.new(products: products.reload).call
  end
end
