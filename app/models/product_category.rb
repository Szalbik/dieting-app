# frozen_string_literal: true

class ProductCategory < ApplicationRecord
  belongs_to :product
  belongs_to :category

  after_commit :enqueue_model_retrain, on: :update, if: :retrain_model?

  scope :pending_without_confirmed_counterpart, lambda {
    joins(:product)
      .includes(:product, :category)
      .where(state: false)
      .where(<<~SQL.squish)
        NOT EXISTS (
          SELECT 1
          FROM product_categories confirmed_pc
          INNER JOIN products confirmed_products ON confirmed_products.id = confirmed_pc.product_id
          WHERE confirmed_pc.state = TRUE
            AND LOWER(confirmed_products.name) = LOWER(products.name)
        )
      SQL
      .order('products.name ASC')
  }

  def self.confirm_pending_for_exact_name(product_name, category_id:)
    joins(:product)
      .where(state: false)
      .where('LOWER(products.name) = LOWER(?)', product_name.to_s.strip)
      .update_all(state: true, category_id: category_id, updated_at: Time.current)
  end

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

  # Updates the state to true for all product categories whose associated product's name
  # matches the given pattern. Optionally, if a new category name is provided, it sets the
  # category to that (creating it if necessary).
  #
  # @param pattern [String] the pattern to match against products.name using SQL LIKE.
  # @param new_category_name [String, nil] optional new category name to assign.
  # @return [Integer] the number of records updated.
  def self.confirm_state_for(pattern, new_category_name = nil)
    scope = joins(:product).where('products.name LIKE ?', "%#{pattern}%")

    if new_category_name.present?
      category = Category.find_or_create_by!(name: new_category_name)
      affected_count = scope.update_all(state: true, category_id: category.id)
      puts "Updated #{affected_count} product category record(s) to state true and set category to '#{new_category_name}' for products matching '%#{pattern}%'."
    else
      affected_count = scope.update_all(state: true)
      puts "Updated #{affected_count} product category record(s) to state true for products matching '%#{pattern}%'."
    end

    affected_count
  end

  private

  def retrain_model?
    state? && (saved_change_to_state? || saved_change_to_category_id?)
  end

  def enqueue_model_retrain
    TrainCategoryModelJob.perform_later
  end
end
