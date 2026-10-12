# frozen_string_literal: true

class ProductCategory < ApplicationRecord
  belongs_to :product
  belongs_to :category

  after_commit :enqueue_model_retrain, on: :update, if: :retrain_model?

  def self.assign_category_for_exact_name!(product_name, category_id:)
    normalized_name = product_name.to_s.strip
    updated_count = joins(:product)
      .where('LOWER(TRIM(products.name)) = ?', normalized_name.downcase)
      .update_all(category_id: category_id, state: true, updated_at: Time.current)

    created_count = 0
    Product
      .left_outer_joins(:product_category)
      .where('LOWER(TRIM(products.name)) = ?', normalized_name.downcase)
      .where(product_categories: { id: nil })
      .find_each do |product|
        create!(product: product, category_id: category_id, state: true)
        created_count += 1
      end

    if updated_count.positive? || created_count.positive?
      TrainCategoryModelJob.perform_later
    end
  end

  private

  def retrain_model?
    state? && (saved_change_to_state? || saved_change_to_category_id?)
  end

  def enqueue_model_retrain
    TrainCategoryModelJob.perform_later
  end
end
