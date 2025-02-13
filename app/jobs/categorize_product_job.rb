# frozen_string_literal: true

class CategorizeProductJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)
    return unless product.present?

    product_category = Classifier::Category.predict(product.name)
    ProductCategory.create(
      category: Category.find_by(name: product_category[:name]),
      product: product,
      state: product_category[:state]
    )
  end
end
