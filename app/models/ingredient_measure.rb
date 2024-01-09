# frozen_string_literal: true

class IngredientMeasure < ApplicationRecord
  belongs_to :product

  def to_s
    "#{amount} #{unit}"
  end
end
