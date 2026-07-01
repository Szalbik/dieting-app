# frozen_string_literal: true

class DietSetsController < ApplicationController
  def show
    @diet_set = owned_diet_sets.find(params[:id])
    @diet = @diet_set.diet
    @recipes = Current.user.recipes.order(:name)
    @other_meals = Meal.joins(diet_set: :diet)
      .where(diets: { user_id: Current.user.id })
      .where.not(diet_set_id: @diet_set.id)
      .includes(diet_set: :diet)
      .order('diets.name, diet_sets.name, meals.id')
  end

  def create
    diet = Current.user.diets.find_by!(id: params[:diet_set][:diet_id], source: 'manual')
    diet_set = diet.diet_sets.create!(name: "Dzień #{diet.diet_sets.count + 1}")
    redirect_to diet_set_path(diet_set)
  end

  def destroy
    diet_set = owned_diet_sets.find(params[:id])
    diet = diet_set.diet
    diet_set.destroy
    redirect_to diet_path(diet), notice: 'Dzień został usunięty.'
  end

  private

  # Only manual (self-authored) diets are editable — PDF and AI-generated
  # diets stay a pristine copy of what was parsed/generated.
  def owned_diet_sets
    DietSet.joins(:diet).where(diets: { user_id: Current.user.id, source: 'manual' })
  end
end
