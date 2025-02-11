# frozen_string_literal: true

class MealPlan < ApplicationRecord
  belongs_to :diet
  belongs_to :diet_set
end
