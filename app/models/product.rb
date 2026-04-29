# frozen_string_literal: true

class Product < ApplicationRecord
  SUGGESTION_FUZZY_THRESHOLD = 0.95

  belongs_to :diet_set, optional: true
  belongs_to :unit, optional: true
  has_many :ingredient_measures, dependent: :destroy
  has_many :meal_plan_product_substitutions, dependent: :destroy
  has_many :shopping_cart_items
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
    grouped_products = group_by_shopping_list_key(scope)
    summed_products = {}

    grouped_products.each_value do |group|
      name = group[:display_name]
      summed_products[name] ||= { measurements: [], category: 'Inne' }

      unit_hash = {}

      group[:products].each do |product|
        product.ingredient_measures.each do |measurement|
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
    grouped_products = group_by_shopping_list_key(scope)
    summed_products = {}

    grouped_products.each_value do |group|
      name = group[:display_name]
      summed_products[name] ||= { measurements: [], category: 'Inne', name: name }

      unit_hash = {}

      group[:products].each do |product|
        product.ingredient_measures.each do |measurement|
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

    prediction = Classifier::Category.predict(name)
    category_match = Category.find_by(name: prediction[:name])
    if category_match.present?
      ProductCategory.create!(
        product: self,
        category: category_match,
        state: prediction[:state] || false
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

    self.original_name ||= name

    resolver = Local::CanonicalProductResolver.new(user: user)
    result = resolver.call(raw_name: name)
    return if result.nil?

    canonical = result.canonical_product
    base_name = base_product_name.presence || base_canonical_product&.name || canonical.name
    preferred_base_name = base_product_name.presence || base_canonical_product&.name || base_name
    base_result = resolver.call(raw_name: base_name, preferred_name: preferred_base_name)

    self.canonical_product      = canonical
    self.base_canonical_product = base_result&.canonical_product if base_result.present?
    self.base_product_name      = base_result&.canonical_product&.name || base_name

    if uncertain_result?(result)
      ProductNameSuggestion.record_suggestion!(
        user:              user,
        raw_name:          original_name || name,
        canonical_product: canonical,
        confidence:        result.confidence,
        match_type:        result.match_type,
        source:            'manual'
      )
    else
      self.name = canonical.name
    end
  end

  def uncertain_result?(result)
    result.match_type == :new ||
      (result.match_type == :fuzzy && result.confidence < SUGGESTION_FUZZY_THRESHOLD)
  end

  def owner_user
    diet_set&.diet&.user || meal&.diet_set&.diet&.user
  end

  def shopping_list_grouping
    self.class.shopping_list_normalizer.call(raw_name: name, canonical_name: canonical_product&.name)
  end

  def shopping_cart_group_name
    shopping_list_grouping[:display_name]
  end

  def shopping_cart_group_key
    shopping_list_grouping[:key]
  end

  def self.shopping_list_normalizer
    @shopping_list_normalizer ||= ShoppingList::ProductNormalizer.new
  end

  def self.best_shopping_list_display_name(products)
    canonical_name = products.filter_map { |product| product.canonical_product&.name }.first
    shopping_list_normalizer.best_display_label(products.map(&:name), canonical_name: canonical_name)
  end

  def self.group_by_shopping_list_key(scope)
    scope.each_with_object({}) do |product, grouped|
      grouping = product.shopping_list_grouping
      key = grouping[:key].presence || shopping_list_normalizer.normalized_name(product.name)
      grouped[key] ||= { display_name: nil, products: [] }
      grouped[key][:products] << product
    end.transform_values do |group|
      group[:display_name] = best_shopping_list_display_name(group[:products])
      group
    end
  end
end
