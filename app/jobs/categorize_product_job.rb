# frozen_string_literal: true

class CategorizeProductJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)
    return unless product.present?

    # Skip if already categorized
    return if product.category.present?

    begin
      product_category = Classifier::Category.predict(product.name)

      if product_category && product_category[:name]
        category = Category.find_by(name: product_category[:name])

        if category
          ProductCategory.create(
            category: category,
            product: product,
            state: product_category[:state] || false
          )
        else
          # Fallback: try to find a similar product
          similar_product = Product.joins(:product_category)
            .where('LOWER(name) LIKE ?', "%#{product.name.downcase}%")
            .where.not(id: product.id)
            .first

          if similar_product&.category.present?
            ProductCategory.create(
              category: similar_product.category,
              product: product,
              state: false
            )
          end
        end
      end
    rescue => e
      Rails.logger.error "Failed to categorize product #{product.id} (#{product.name}): #{e.message}"

      # Fallback: try to find a similar product
      similar_product = Product.joins(:product_category)
        .where('LOWER(name) LIKE ?', "%#{product.name.downcase}%")
        .where.not(id: product.id)
        .first

      if similar_product&.category.present?
        ProductCategory.create(
          category: similar_product.category,
          product: product,
          state: false
        )
      end
    end
  end
end
