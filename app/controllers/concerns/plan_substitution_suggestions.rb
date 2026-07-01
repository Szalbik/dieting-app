# frozen_string_literal: true

# Shared substitution-suggestion precompute for controllers that render
# diet_set_plans/_ingredient_row (DietSetPlansController's own plan view and
# MealPlansController's single-meal view). Bulk-loads @replacement_cycles /
# @local_substitutions_by_key for a set of meal_plans so the partial doesn't
# fire one query per ingredient row.
module PlanSubstitutionSuggestions
  extend ActiveSupport::Concern

  private

  def load_substitution_suggestions(meal_plans:)
    @replacement_cycles = {}
    @local_substitutions_by_key = {}
    meal_plans = Array(meal_plans)
    return if meal_plans.empty?

    # One query for all of these meal plans' user substitutions, grouped for
    # O(1) per-row lookup in the view (was one query per ingredient row).
    @local_substitutions_by_key = Current.user.meal_plan_product_substitutions
      .where(meal_plan: meal_plans)
      .ordered
      .group_by { |sub| [sub.meal_plan_id, sub.product_id] }

    # Build product_id => [meal_plan, product] from the already-preloaded
    # associations instead of a SQL `exists?` per candidate per product.
    meal_plan_by_product = {}
    meal_plans.each do |meal_plan|
      meal_plan.products.each { |product| meal_plan_by_product[product.id] ||= [meal_plan, product] }
    end

    meal_plan_by_product.each_value do |meal_plan, product|
      base_name = resolve_base_name_for(product, meal_plan: meal_plan)
      @replacement_cycles[product.id] = display_cycle_for(
        meal_plan: meal_plan,
        product: product,
        base_name: base_name,
        original_name: original_name_for(meal_plan: meal_plan, product: product)
      )
    end
  end

  def resolve_base_name_for(product, meal_plan: nil)
    explicit = ProductSubstitution.strip_quantity_from_name(product.base_product_name.to_s)
    current_name = ProductSubstitution.strip_quantity_from_name(product.name.to_s)
    return explicit if candidate_cycle_for(explicit, meal_plan: meal_plan, product: product).size > 1

    base_canonical_name = product.base_canonical_product&.name
    return base_canonical_name if candidate_cycle_for(base_canonical_name, meal_plan: meal_plan, product: product).size > 1

    product_norm = ProductSubstitution.normalize_name(product.name)
    match = Current.user.substitution_product_matches.find do |m|
      match_norm = ProductSubstitution.normalize_name(m.matched_product_name)
      match_norm == product_norm || product_norm.include?(match_norm) || match_norm.include?(product_norm)
    end
    matched_source = ProductSubstitution.strip_quantity_from_name(match&.source_product)
    return matched_source if candidate_cycle_for(matched_source, meal_plan: meal_plan, product: product).size > 1

    explicit_differs_from_current = explicit.present? &&
      ProductSubstitution.normalize_name(explicit) != ProductSubstitution.normalize_name(current_name)
    return explicit if explicit_differs_from_current

    return explicit if explicit.present?
    return base_canonical_name if base_canonical_name.present?
    return product.canonical_product.name if product.canonical_product.present?

    ProductSubstitution.strip_quantity_from_name(product.name)
  end

  def candidate_cycle_for(base_name, meal_plan: nil, product: nil)
    return [] if base_name.blank? || Current.user.blank?

    # Request-scoped memo: same (base_name, meal_plan, product) yields the same
    # result within a request, and resolve_base_name_for/display_cycle_for call
    # this repeatedly with overlapping base names across products.
    @candidate_cycle_memo ||= {}
    cache_key = [base_name, meal_plan&.id, product&.id]
    return @candidate_cycle_memo[cache_key] if @candidate_cycle_memo.key?(cache_key)

    result =
      if meal_plan.present? && product.present?
        local_cycle = MealPlanProductSubstitution.local_cycle_for(
          user: Current.user,
          meal_plan: meal_plan,
          product: product,
          base_name: base_name
        )
        local_cycle.size > 1 ? local_cycle : ProductSubstitution.local_cycle_for(user: Current.user, base_name: base_name)
      else
        ProductSubstitution.local_cycle_for(user: Current.user, base_name: base_name)
      end

    @candidate_cycle_memo[cache_key] = result
  end

  def display_cycle_for(meal_plan:, product:, base_name:, original_name:)
    substitutions = candidate_cycle_for(base_name, meal_plan: meal_plan, product: product)
    original = ProductSubstitution.strip_quantity_from_name(original_name.to_s)
    return substitutions if original.blank?

    [original, *substitutions.reject { |name| same_name?(name, original) || same_name?(name, base_name) }].uniq
  end

  def original_name_for(meal_plan:, product:)
    return if meal_plan.blank? || product.blank?

    OriginalMealIngredientResolver.new(meal: meal_plan.meal).original_name_for(product: product)
  end

  def same_name?(left, right)
    ProductSubstitution.normalize_name(left) == ProductSubstitution.normalize_name(right)
  end

  def resolve_base_canonical_product_for(product)
    product.base_canonical_product ||
      resolve_canonical_product(product.base_product_name) ||
      resolve_canonical_product(product.name)
  end

  def resolve_canonical_product(raw_name)
    return if raw_name.blank?

    Local::CanonicalProductResolver.new(user: Current.user).call_for_canonical(raw_name: raw_name)
  end
end
