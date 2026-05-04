# frozen_string_literal: true

class CategorizeProductJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find_by(id: product_id)
    return if product.nil?
    return if product.category.present?

    prediction = Classifier::Category.predict(product.name)
    return if prediction[:name].blank?

    category = Category.find_by(name: prediction[:name])
    return if category.blank?

    ProductCategory.create!(
      category: category,
      product: product,
      state: prediction[:state] || false
    )
  rescue StandardError => e
    Rails.logger.error "Failed to categorize product #{product_id}: #{e.message}"
  end
end
