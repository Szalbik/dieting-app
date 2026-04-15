# frozen_string_literal: true

class AddActiveToDiets < ActiveRecord::Migration[7.1]
  def change
    add_column :diets, :active, :boolean, null: false, default: true
  end
end
