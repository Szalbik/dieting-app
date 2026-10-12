# frozen_string_literal: true

class MealPlansController < ApplicationController
  include PlanSubstitutionSuggestions

  before_action :set_meal_plan

  def show
    load_substitution_suggestions(meal_plans: [@meal_plan])
  end

  def toggle_eaten
    @meal_plan.update(eaten: !@meal_plan.eaten)
    notice = @meal_plan.eaten? ? "Smacznego! #{@meal_plan.name} oznaczone jako zjedzone." : "#{@meal_plan.name} — cofnięto oznaczenie."
    redirect_to diet_set_plans_path(date: @meal_plan.diet_set_plan.date), notice: notice
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
