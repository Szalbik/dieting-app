# frozen_string_literal: true

class AddMealsPerDayToDiets < ActiveRecord::Migration[8.0]
  def change
    add_column :diets, :meals_per_day, :integer
  end
end
