# frozen_string_literal: true

require 'digest'

class DietSetPlansController < ApplicationController
  include PlanSubstitutionSuggestions

  before_action :set_diet_set_plan, only: [:show, :toggle_shopping_bag]

  def toggle_shopping_bag
    @meal_plan = MealPlan.joins(diet_set_plan: :diet).find_by!(id: params[:id], diets: { user_id: Current.user.id })
    @meal_plan.update(selected_for_cart: !@meal_plan.selected_for_cart)
    sync_current_shopping_cart!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to diet_set_plans_path(date: date) }
    end
  end

  def show
    if Current.user.active_diets.empty?
      redirect_to new_diet_path, warning: 'You need to create a diet first.'
    end

    recover_missing_measures_if_needed
    preload_plan_associations
    preload_swap_day_plans
    # Plan dnia no longer renders ingredient rows (moved to meal_plans#show),
    # so the per-product substitution precompute is dead weight here.
    @replacement_cycles = {}

    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    diet_set = DietSet.find(diet_set_plan_params[:diet_set_id])
    @diet_set_plan = DietSetPlan.new(date: date, diet_set: diet_set, diet: diet_set.diet)

    if @diet_set_plan.save
      Current.user.diet_set_plans.where(date: date).update_all(shopping_done: false)
      diet_set.meals.each do |meal|
        @diet_set_plan.meal_plans.create!(meal: meal)
      end
      sync_current_shopping_cart!
      redirect_to diet_set_plans_path(date: date), notice: 'Meal plan was successfully updated.'
    else
      render :show
    end
  end

  def swap
    current_date = Date.parse(params[:current_date])
    target_date = Date.parse(params[:target_date])

    current_plan = Current.user.diet_set_plans.where(date: current_date).order(created_at: :desc).first
    target_plan = Current.user.diet_set_plans.where(date: target_date).order(created_at: :desc).first

    if current_plan.nil? && target_plan.nil?
      redirect_to diet_set_plans_path(date: current_date), alert: 'Żaden z wybranych dni nie ma przypisanej diety.'
      return
    end

    ActiveRecord::Base.transaction do
      if current_plan && target_plan
        temp_date = Date.new(1900, 1, 1)
        current_plan.update!(date: temp_date)
        target_plan.update!(date: current_date)
        current_plan.update!(date: target_date)
      elsif current_plan
        current_plan.update!(date: target_date)
      else
        target_plan.update!(date: current_date)
      end
    end

    sync_current_shopping_cart!
    redirect_to diet_set_plans_path(date: current_date), notice: 'Zestawy diety zostały zamienione.'
  rescue Date::Error
    redirect_to diet_set_plans_path, alert: 'Nieprawidłowy format daty.'
  end

  def replace_product
    meal_plan = MealPlan
      .joins(diet_set_plan: :diet)
      .find_by(id: replace_product_params[:meal_plan_id], diets: { user_id: Current.user.id })

    unless meal_plan
      redirect_to diet_set_plans_path(date: date), alert: 'Nie znaleziono posiłku do podmiany.'
      return
    end

    product = meal_plan.products.find_by(id: replace_product_params[:product_id])
    replacement_name = ProductSubstitution.strip_quantity_from_name(replace_product_params[:replacement_name].to_s)

    if product.blank? || replacement_name.blank?
      redirect_to diet_set_plans_path(date: date), alert: 'Podaj poprawny produkt zamienny.'
      return
    end

    product = localize_product_for_meal_plan(meal_plan: meal_plan, product: product)

    ActiveRecord::Base.transaction do
      product.update!(
        name: replacement_name,
        base_product_name: product.base_product_name.presence || product.name
      )
      product.product_category&.destroy
      product.categorize_if_needed
    end

    redirect_to diet_set_plans_path(date: date), notice: 'Produkt został trwale podmieniony w posiłku.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to diet_set_plans_path(date: date), alert: "Nie udało się podmienić produktu: #{e.message}"
  end

  def cycle_product_replacement
    meal_plan = MealPlan
      .joins(diet_set_plan: :diet)
      .find_by(id: params[:meal_plan_id], diets: { user_id: Current.user.id })

    unless meal_plan
      redirect_to diet_set_plans_path(date: date), alert: 'Nie znaleziono posiłku do podmiany.'
      return
    end

    product = meal_plan.products.find_by(id: params[:product_id])
    unless product
      redirect_to diet_set_plans_path(date: date), alert: 'Nie znaleziono produktu do podmiany.'
      return
    end

    row_dom_id = view_context.dom_id(product, :ingredient_row)
    product = localize_product_for_meal_plan(meal_plan: meal_plan, product: product)
    original_name = original_name_for(meal_plan: meal_plan, product: product)
    base_name = resolve_base_name_for(product, meal_plan: meal_plan)
    base_canonical_product = resolve_canonical_product(base_name) || resolve_base_canonical_product_for(product)
    cycle_candidates = display_cycle_for(
      meal_plan: meal_plan,
      product: product,
      base_name: base_name,
      original_name: original_name
    )
    cycle_candidates = sensible_cycle_candidates(
      meal_plan: meal_plan,
      product: product,
      base_name: base_name,
      cycle_candidates: cycle_candidates
    )
    current_in_cycle = cycle_candidates.any? do |name|
      ProductSubstitution.normalize_name(name) == ProductSubstitution.normalize_name(product.name)
    end

    if cycle_candidates.size < 2
      redirect_to diet_set_plans_path(date: date), alert: 'Brak dostępnych zamienników dla tego produktu.'
      return
    end

    if current_in_cycle
      current_idx = cycle_candidates.index { |name|
 ProductSubstitution.normalize_name(name) == ProductSubstitution.normalize_name(product.name) } || 0
      next_name = cycle_candidates[(current_idx + 1) % cycle_candidates.size]
    else
      # If current product is a mapped variant not present in cycle labels,
      # jump to first actual replacement after base.
      next_name = cycle_candidates[1] || cycle_candidates.first
    end

    factor_from_name = same_name?(product.name, original_name) ? base_name : product.name
    factor_to_name = same_name?(next_name, original_name) ? base_name : next_name

    factor = factor_for_cycle(
      meal_plan: meal_plan,
      product: product,
      base_name: base_name,
      from_name: factor_from_name,
      to_name: factor_to_name
    )
    factor = 1.0 if factor <= 0

    ActiveRecord::Base.transaction do
      product.update!(
        name: ProductSubstitution.strip_quantity_from_name(next_name),
        base_product_name: base_name,
        canonical_product: resolve_canonical_product(next_name),
        base_canonical_product: base_canonical_product
      )
      if factor != 1.0
        product.ingredient_measures.each do |measure|
          next unless measure.amount.present?

          measure.update!(amount: (measure.amount.to_f * factor).round(2))
        end
      end
      product.product_category&.destroy
      product.categorize_if_needed
    end

    respond_to do |format|
      format.turbo_stream do
        prepare_plan_for_refresh
        flash.now[:notice] = "Podmieniono na: #{next_name}"
        render turbo_stream: [
          turbo_stream.replace(
            'flash',
            partial: 'shared/flash',
            locals: { flash: flash }
          ),
          turbo_stream.replace(
            row_dom_id,
            partial: 'diet_set_plans/ingredient_row',
            locals: { meal_plan: meal_plan, product: product.reload }
          ),
        ]
      end
      format.html { redirect_to diet_set_plans_path(date: date), notice: "Podmieniono na: #{next_name}" }
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to diet_set_plans_path(date: date), alert: "Nie udało się podmienić produktu: #{e.message}"
  end

  def add_product_substitution
    meal_plan = MealPlan
      .joins(diet_set_plan: :diet)
      .find_by(id: product_substitution_params[:meal_plan_id], diets: { user_id: Current.user.id })

    unless meal_plan
      redirect_to diet_set_plans_path(date: date), alert: 'Nie znaleziono posiłku.'
      return
    end

    product = meal_plan.products.find_by(id: product_substitution_params[:product_id])
    unless product
      redirect_to diet_set_plans_path(date: date), alert: 'Nie znaleziono produktu.'
      return
    end

    substitution = Current.user.meal_plan_product_substitutions.new(
      meal_plan: meal_plan,
      product: product,
      replacement_product: product_substitution_params[:replacement_name].presence ||
        product_substitution_params[:replacement_product],
      replacement_amount: product_substitution_params[:replacement_amount],
      replacement_unit: product_substitution_params[:replacement_unit]
    )
    substitution.capture_source_from!(
      product: product,
      base_name: resolve_base_name_for(product, meal_plan: meal_plan)
    )

    if substitution.save
      render_product_row_update(meal_plan: meal_plan, product: product, notice: 'Zamiennik został dodany do tego posiłku.')
    else
      render_product_row_update(meal_plan: meal_plan, product: product, alert: substitution.errors.full_messages.to_sentence)
    end
  end

  def remove_product_substitution
    substitution = Current.user.meal_plan_product_substitutions.find_by(id: params[:substitution_id])
    unless substitution
      redirect_to diet_set_plans_path(date: date), alert: 'Nie znaleziono zamiennika.'
      return
    end

    meal_plan = substitution.meal_plan
    product = substitution.product
    substitution.destroy

    render_product_row_update(meal_plan: meal_plan, product: product, notice: 'Zamiennik został usunięty z tego posiłku.')
  end

  private

  def set_diet_set_plan
    @diet_set_plan = Current.user.diet_set_plans.where(date: date).sort.last unless params['reassign'].present?
    @diet_set_plan ||= DietSetPlan.new(date: date)
  end

  def date
    @date = params['date'].present? ? Date.parse(params['date']).to_s : Date.current.to_s
  end

  def diet_set_plan_params
    params.require(:diet_set_plan).permit(:diet_set_id)
  end

  def replace_product_params
    params.permit(:meal_plan_id, :product_id, :replacement_name)
  end

  def product_substitution_params
    params.permit(:meal_plan_id, :product_id, :replacement_product, :replacement_name, :replacement_amount, :replacement_unit)
  end

  def shopping_cart
    @_shopping_cart ||= Current.user.shopping_cart
  end

  def sync_current_shopping_cart!
    ShoppingCartSyncService.new(
      shopping_cart: shopping_cart,
      users: shopping_cart.member_users
    ).call
  end

  def recover_missing_measures_if_needed
    return unless @diet_set_plan&.persisted?

    diet = @diet_set_plan.diet
    return unless diet&.parsed_json.is_a?(Array)
    return unless @diet_set_plan.meal_plans.joins(:products).left_outer_joins(products: :ingredient_measures).where(ingredient_measures: { id: nil }).exists?

    restored_count = DietMeasureRecoveryService.new(diet: diet).call
    return unless restored_count.positive?

    @diet_set_plan = Current.user.diet_set_plans.where(date: date).sort.last || @diet_set_plan
  rescue StandardError => e
    Rails.logger.warn("Diet measure recovery failed for diet_set_plan #{@diet_set_plan&.id}: #{e.message}")
  end

  # Eager-load the whole render tree for #show so the view (per-meal,
  # per-product) and load_substitution_suggestions don't trigger N+1s.
  def preload_plan_associations
    return unless @diet_set_plan&.persisted?

    ActiveRecord::Associations::Preloader.new(
      records: [@diet_set_plan],
      associations: {
        meal_plans: [
          :meal,
          :meal_plan_product_substitutions,
          { products: [:ingredient_measures, :base_canonical_product, :canonical_product, { product_category: :category }] },
        ],
      }
    ).call
  end

  # Preload the 7-day swap-picker window once instead of one query (+ meals
  # queries via derived_name_from_meal) per day on every page render.
  def preload_swap_day_plans
    plans = Current.user.diet_set_plans
      .where(date: (Date.current - 1.day)..(Date.current + 5.days))
      .order(created_at: :desc)
      .to_a

    ActiveRecord::Associations::Preloader.new(records: plans, associations: :meals).call

    @swap_day_plans = {}
    plans.each { |plan| @swap_day_plans[plan.date] ||= plan }
  end

  def prepare_plan_for_refresh
    @diet_set_plan = Current.user.diet_set_plans.where(date: date).sort.last
    @diet_set_plan ||= DietSetPlan.new(date: date)
    load_substitution_suggestions(meal_plans: @diet_set_plan.meal_plans)
  end

  def sensible_cycle_candidates(meal_plan:, product:, base_name:, cycle_candidates:)
    return cycle_candidates if cycle_candidates.size <= 2
    return cycle_candidates if local_substitutions_enabled_for?(meal_plan: meal_plan, product: product)
    return cycle_candidates unless ai_meal_filter_enabled?

    key_payload = [
      meal_plan.name,
      meal_plan.products.pluck(:name).sort.join('|'),
      base_name,
      cycle_candidates.join('|'),
    ].join('::')
    cache_key = "meal-replacements:v1:#{Digest::SHA256.hexdigest(key_payload)}"

    allowed = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      Chat::MealReplacementSuitabilityService.new(
        meal_name: meal_plan.name,
        ingredient_names: meal_plan.products.pluck(:name),
        current_product_name: product.name,
        base_product_name: base_name,
        candidate_names: cycle_candidates
      ).call
    end

    allowed_norm = Array(allowed).map { |name| ProductSubstitution.normalize_name(name) }
    base_norm = ProductSubstitution.normalize_name(base_name)
    current_norm = ProductSubstitution.normalize_name(product.name)

    filtered = cycle_candidates.select do |candidate|
      norm = ProductSubstitution.normalize_name(candidate)
      allowed_norm.include?(norm) || norm == base_norm || norm == current_norm
    end
    filtered.size >= 2 ? filtered : cycle_candidates
  rescue StandardError
    cycle_candidates
  end

  def ai_meal_filter_enabled?
    !Rails.env.test?
  end

  def local_substitutions_enabled_for?(meal_plan:, product:)
    MealPlanProductSubstitution.for_product(
      user: Current.user,
      meal_plan: meal_plan,
      product: product
    ).exists?
  end

  def factor_for_cycle(meal_plan:, product:, base_name:, from_name:, to_name:)
    if local_substitutions_enabled_for?(meal_plan: meal_plan, product: product)
      return MealPlanProductSubstitution.local_factor_for(
        user: Current.user,
        meal_plan: meal_plan,
        product: product,
        base_name: base_name,
        from_name: from_name,
        to_name: to_name
      ).to_f
    end

    ProductSubstitution.local_factor_for(
      user: Current.user,
      base_name: base_name,
      from_name: from_name,
      to_name: to_name
    ).to_f
  end

  def localize_product_for_meal_plan(meal_plan:, product:)
    MealPlanMealLocalizer.new(meal_plan: meal_plan).localize_product(product: product)
  end

  def render_product_row_update(meal_plan:, product:, notice: nil, alert: nil)
    respond_to do |format|
      format.turbo_stream do
        prepare_plan_for_refresh
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        render turbo_stream: [
          turbo_stream.replace(
            'flash',
            partial: 'shared/flash',
            locals: { flash: flash }
          ),
          turbo_stream.replace(
            view_context.dom_id(product, :ingredient_row),
            partial: 'diet_set_plans/ingredient_row',
            locals: { meal_plan: meal_plan, product: product.reload }
          ),
        ]
      end
      format.html do
        redirect_to diet_set_plans_path(date: date), notice: notice, alert: alert
      end
    end
  end
end
