# frozen_string_literal: true

class Product < ApplicationRecord
  belongs_to :diet_set, optional: true
  belongs_to :unit, optional: true
  has_many :ingredient_measures, dependent: :destroy
  has_one :product_category, dependent: :destroy, inverse_of: :product
  has_one :category, through: :product_category
  belongs_to :meal, optional: true
  belongs_to :canonical_product, optional: true
  belongs_to :base_canonical_product, class_name: 'CanonicalProduct', optional: true

  # products without category
  scope :uncategorized, -> { includes(:product_category).where(product_categories: { id: nil }) }

  before_validation :sync_canonical_products!

  # Automatically categorize products when they are created
  after_create :categorize_if_needed

  # Class method to categorize all uncategorized products
  def self.categorize_all_uncategorized!
    uncategorized.find_each do |product|
      product.categorize_if_needed
    end
  end

  # Manual categorization method for console testing
  def self.manual_categorize!(product_name, category_name)
    product = find_by(name: product_name)
    return "Product not found: #{product_name}" unless product

    category = Category.find_by(name: category_name)
    return "Category not found: #{category_name}" unless category

    if product.category.present?
      return "Product already has category: #{product.category.name}"
    end

    ProductCategory.create!(
      product: product,
      category: category,
      state: true
    )

    "Successfully categorized: #{product_name} -> #{category_name}"
  end

  # Test method to check categorization
  def self.test_categorization(product_name)
    product = find_by(name: product_name)
    return "Product not found: #{product_name}" unless product

    if product.category.present?
      "Product '#{product.name}' has category: #{product.category.name}"
    else
      "Product '#{product.name}' has no category. Attempting to categorize..."
      categorize_if_needed
      "Categorization job queued for #{product.name}"
    end
  end

  def self.group_and_sum_by_name_and_unit(scope = Product)
    # Eager load ingredient measures
    # products_with_measures = scope.includes(:ingredient_measures, :category)

    # Group products by name
    grouped_by_name = scope.group_by(&:name)

    # Initialize a hash to store the summed products
    summed_products = {}

    grouped_by_name.each do |name, products|
      summed_products[name] ||= { measurements: [], category: 'Inne' }

      # Initialize a hash to store the summed amounts for each unit
      unit_hash = {}

      products.each do |product|
        # Fetch ingredient measurements for the product
        ingredient_measurements = product.ingredient_measures

        # Sum the amounts by unit for this product
        ingredient_measurements.each do |measurement|
          unit = measurement.unit || 'No Unit'
          amount = measurement.amount || 0
          unit_hash[unit] ||= 0
          unit_hash[unit] += amount
        end

        summed_products[name][:category] = product.category.name if product.category.present?
      end

      unit_hash.each do |unit, amount|
        summed_products[name][:measurements] << { unit: unit, amount: amount }
      end
    end

    # sort by category in desc order
    summed_products.sort_by { |k, v| v[:category] }.reverse
  end

  def self.group_and_sum_by_name_then_category(scope = Product)
    # Eager load ingredient measures and category
    # products_with_measures = scope.includes(:ingredient_measures, :category)

    # Group products by name
    grouped_by_name = scope.group_by(&:name)

    # Initialize a hash to store the summed products
    summed_products = {}

    grouped_by_name.each do |name, products|
      summed_products[name] ||= { measurements: [], category: 'Inne', name: name }

      # Initialize a hash to store the summed amounts for each unit
      unit_hash = {}

      products.each do |product|
        # Fetch ingredient measurements for the product
        ingredient_measurements = product.ingredient_measures

        # Sum the amounts by unit for this product
        ingredient_measurements.each do |measurement|
          unit = measurement.unit || 'No Unit'
          amount = measurement.amount || 0
          unit_hash[unit] ||= 0
          unit_hash[unit] += amount
        end

        summed_products[name][:category] = product.category.name if product.category.present?
      end

      unit_hash.each do |unit, amount|
        summed_products[name][:measurements] << { unit: unit, amount: amount }
      end
    end

    # Now group the summed products by category
    grouped_by_category = summed_products.group_by { |_name, data| data[:category] || 'Inne' }

    # # Transform the hash to keep only the measurements
    grouped_by_category.transform_values do |products|
      products.flat_map { |_name, data| data }
    end
  end

  def categorize_if_needed
    # Only categorize if the product doesn't already have a category
    return if category.present?

    # Try to find a similar product that's already categorized
    similar_product = Product.joins(:product_category)
      .where('LOWER(name) LIKE ?', "%#{name.downcase}%")
      .where.not(id: id)
      .first

    if similar_product&.category.present?
      # Use the same category as the similar product
      ProductCategory.create!(
        product: self,
        category: similar_product.category,
        state: false
      )
      return
    end

    # Trigger the categorization job
    CategorizeProductJob.perform_later(id)
  end

  # Get a reasonable category name, with fallback to "Inne"
  def category_name_or_default
    category&.name || 'Inne'
  end

  def sync_canonical_products!
    user = owner_user
    return if user.blank? || name.blank?

    resolver = Local::CanonicalProductResolver.new(user: user)
    resolved_product = resolver.call(raw_name: name)
    return if resolved_product.blank?

    base_name = base_product_name.presence || base_canonical_product&.name || resolved_product.name
    preferred_base_name = base_product_name.presence || base_canonical_product&.name || base_name
    resolved_base = resolver.call(raw_name: base_name, preferred_name: preferred_base_name)

    self.canonical_product = resolved_product
    self.base_canonical_product = resolved_base if resolved_base.present?
    self.name = resolved_product.name
    self.base_product_name = resolved_base&.name || base_name
  end

  def owner_user
    diet_set&.diet&.user || meal&.diet_set&.diet&.user
  end
end
