# frozen_string_literal: true

class DietSetPlan < ApplicationRecord
  SERVINGS_RANGE = 1..10

  belongs_to :diet
  belongs_to :diet_set
  has_many :meal_plans, dependent: :destroy

  has_many :meals, through: :diet_set
  has_many :products, through: :meals

  delegate :name, to: :diet_set
  delegate :derived_name_from_meal, to: :diet_set

  validates :servings, numericality: { only_integer: true, in: SERVINGS_RANGE }

  def nutrition_totals
    {
      kcal: meal_plans.sum { |mp| mp.kcal || 0 },
      protein: meal_plans.sum { |mp| mp.protein || 0 },
      fat: meal_plans.sum { |mp| mp.fat || 0 },
      carbs: meal_plans.sum { |mp| mp.carbs || 0 },
    }
  end
end
