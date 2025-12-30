# frozen_string_literal: true

class MealPlan < ApplicationRecord
  belongs_to :diet_set_plan
  belongs_to :meal

  has_many :products, through: :meal

  delegate :name, to: :meal
  delegate :instructions, to: :meal
  delegate :kcal, :protein, :fat, :carbs, to: :meal
end
