# frozen_string_literal: true

class MealPlansController < ApplicationController
  include PlanSubstitutionSuggestions

  before_action :set_meal_plan

  def show
    load_substitution_suggestions(meal_plans: [@meal_plan])
  end

  # An explicit `eaten` target makes the request idempotent (offline outbox replay); without it, flip.
  def toggle_eaten
    eaten = params[:eaten].present? ? ActiveModel::Type::Boolean.new.cast(params[:eaten]) == true : !@meal_plan.eaten
    @meal_plan.update(eaten: eaten)

    respond_to do |format|
      format.turbo_stream { head :no_content } # outbox: the button was already painted client-side
      format.html do
        notice = @meal_plan.eaten? ? "Smacznego! #{@meal_plan.name} oznaczone jako zjedzone." : "#{@meal_plan.name} — cofnięto oznaczenie."
        redirect_to diet_set_plans_path(date: @meal_plan.diet_set_plan.date), notice: notice
      end
    end
  end

  private

  def set_meal_plan
    @meal_plan = MealPlan
      .joins(diet_set_plan: :diet)
      .find_by!(id: params[:id], diets: { user_id: Current.user.id })

    ActiveRecord::Associations::Preloader.new(
      records: [@meal_plan],
      associations: [
        :meal,
        { products: [:ingredient_measures, :base_canonical_product, :canonical_product, { product_category: :category }] },
      ]
    ).call
  end
end
