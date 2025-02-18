# frozen_string_literal: true

class MealPlan < ApplicationRecord
  belongs_to :diet
  belongs_to :diet_set
  has_many :meals, through: :diet_set
  has_many :products, through: :meals
end
