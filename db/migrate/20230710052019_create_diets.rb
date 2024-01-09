# frozen_string_literal: true

class CreateDiets < ActiveRecord::Migration[7.0]
  def change
    create_table :diets, &:timestamps
  end
end
