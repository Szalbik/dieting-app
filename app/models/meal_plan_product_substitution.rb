# frozen_string_literal: true

class MealPlanProductSubstitution < ApplicationRecord
  belongs_to :user
  belongs_to :meal_plan
  belongs_to :product
  belongs_to :replacement_canonical_product, class_name: 'CanonicalProduct', optional: true

  validates :source_product, :replacement_product, presence: true
  validates :replacement_product, uniqueness: { scope: [:user_id, :meal_plan_id, :product_id] }

  before_validation :normalize_replacement_and_quantities
  before_validation :sync_canonical_product!

  normalizes :source_product, with: ->(value) { value.to_s.strip.presence }
  normalizes :replacement_product, with: ->(value) { value.to_s.strip.presence }

  scope :ordered, -> { order(:created_at, :id) }

  def self.local_replacements_for(user:, meal_plan:, product:)
    for_product(user: user, meal_plan: meal_plan, product: product)
      .ordered
      .map { |sub| sub.replacement_canonical_product&.name || ProductSubstitution.strip_quantity_from_name(sub.replacement_product) }
      .then { |names| ProductSubstitution.canonical_dedup(names) }
  end

  def self.local_cycle_for(user:, meal_plan:, product:, base_name:)
    base_clean = ProductSubstitution.canonical_name_for_user(user: user, raw_name: base_name)
    ProductSubstitution.canonical_dedup([base_clean, *local_replacements_for(user: user, meal_plan: meal_plan, product: product)])
  end

  def self.local_factor_for(user:, meal_plan:, product:, base_name:, from_name:, to_name:)
    substitutions = for_product(user: user, meal_plan: meal_plan, product: product).to_a
    return 1.0 if substitutions.empty?

    base_norm = ProductSubstitution.normalize_name(base_name)
    from_norm = ProductSubstitution.normalize_name(from_name)
    to_norm = ProductSubstitution.normalize_name(to_name)
    return 1.0 if from_norm.blank? || to_norm.blank? || from_norm == to_norm

    pairs = substitutions.each_with_object({}) do |sub, output|
      replacement_norm = ProductSubstitution.normalize_name(sub.replacement_product)
      next if replacement_norm.blank?

      output[replacement_norm] = ProductSubstitution.multiplier_for(sub)
    end

    if from_norm == base_norm
      ratio = pairs[to_norm]
      return ratio if ratio.present? && ratio.positive?
      return 1.0
    end

    if to_norm == base_norm
      ratio = pairs[from_norm]
      return 1.0 if ratio.blank? || ratio <= 0

      return 1.0 / ratio
    end

    from_ratio = pairs[from_norm]
    to_ratio = pairs[to_norm]
    return 1.0 if from_ratio.blank? || to_ratio.blank? || from_ratio <= 0

    to_ratio / from_ratio
  end

  def self.for_product(user:, meal_plan:, product:)
    where(user: user, meal_plan: meal_plan, product: product)
  end

  def capture_source_from!(product:, base_name:)
    self.source_product = ProductSubstitution.strip_quantity_from_name(base_name.presence || product.base_product_name.presence || product.name)

    measure = product.ingredient_measures.order(:id).first
    return if measure.blank?

    self.source_amount = measure.amount if measure.amount.present?
    self.source_unit = ProductSubstitution.normalize_unit(measure.unit) if measure.unit.present?
  end

  def replacement_label
    return replacement_product if replacement_amount.blank? || replacement_unit.blank?

    "#{replacement_product} #{formatted_amount(replacement_amount)} #{replacement_unit}"
  end

  private

  def normalize_replacement_and_quantities
    self.source_unit = ProductSubstitution.normalize_unit(source_unit) if source_unit.present?
    self.replacement_unit = ProductSubstitution.normalize_unit(replacement_unit) if replacement_unit.present?

    rep_amount, rep_unit, rep_scale, rep_name = ProductSubstitution.parse_quantity_from_text(replacement_product)

    self.replacement_product = rep_name
    self.replacement_amount = rep_amount if rep_amount.present?
    self.replacement_unit = rep_unit if rep_unit.present?

    effective_source_amount = source_amount
    effective_replacement_amount = rep_amount.presence || replacement_amount
    effective_source_scale = ProductSubstitution.unit_scale(source_unit)
    effective_replacement_scale = rep_scale.presence || ProductSubstitution.unit_scale(replacement_unit)

    if effective_source_amount.present? && effective_replacement_amount.present? &&
        effective_source_scale.present? && effective_replacement_scale.present? &&
        effective_source_scale.first == effective_replacement_scale.first
      source_base = effective_source_amount.to_f * effective_source_scale.last
      replacement_base = effective_replacement_amount.to_f * effective_replacement_scale.last
      self.amount_multiplier = source_base.positive? ? (replacement_base / source_base) : amount_multiplier
    end
  end

  def formatted_amount(value)
    numeric = value.to_f
    numeric == numeric.to_i ? numeric.to_i : numeric.round(2)
  end

  def sync_canonical_product!
    return if user.blank? || replacement_product.blank?

    replacement = Local::CanonicalProductResolver.new(user: user).call(raw_name: replacement_product)
    return if replacement.blank?

    self.replacement_canonical_product = replacement
    self.replacement_product = replacement.name
  end
end
