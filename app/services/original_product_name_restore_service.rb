# frozen_string_literal: true

class OriginalProductNameRestoreService
  def initialize(diet:)
    @diet = diet
  end

  def call
    return 0 if @diet.blank?

    updated = 0

    @diet.meals.includes(:products, diet_set: :diet).find_each do |meal|
      resolver = OriginalMealIngredientResolver.new(meal: meal)

      meal.products.order(:id).each do |product|
        original_name = resolver.original_name_for(product: product).to_s.strip
        next if original_name.blank?
        next unless should_restore_original_name?(product: product, original_name: original_name)

        product.update!(name: original_name)
        updated += 1
      end
    end

    updated
  end

  private

  def should_restore_original_name?(product:, original_name:)
    current_name = ProductSubstitution.strip_quantity_from_name(product.name)
    base_name = ProductSubstitution.strip_quantity_from_name(product.base_product_name)
    original_norm = ProductSubstitution.normalize_name(original_name)
    current_norm = ProductSubstitution.normalize_name(current_name)
    base_norm = ProductSubstitution.normalize_name(base_name)

    return false if original_norm == current_norm
    return false unless base_norm.present? && current_norm == base_norm

    true
  end
end
