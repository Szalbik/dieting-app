# frozen_string_literal: true

class CategorizeProductsJob < ApplicationJob
  queue_as :default

  def perform
    Product.uncategorized.each do |product|
      CategorizeProductJob.perform_later(product.id)
    end
  end
end
