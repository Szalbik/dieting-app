# frozen_string_literal: true

class DietSetPlan < ApplicationRecord
  belongs_to :diet
  belongs_to :diet_set
  has_many :meal_plans, dependent: :destroy

  has_many :meals, through: :diet_set
  has_many :products, through: :meals

  delegate :name, to: :diet_set
  delegate :derived_name_from_meal, to: :diet_set
end
