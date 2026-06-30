# frozen_string_literal: true

class MealPlansController < ApplicationController
  before_action :set_meal_plan

  def show; end

  def toggle_eaten
    @meal_plan.update(eaten: !@meal_plan.eaten)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to meal_plan_path(@meal_plan) }
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
