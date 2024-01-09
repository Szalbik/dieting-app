# frozen_string_literal: true

class AddUnitToProducts < ActiveRecord::Migration[7.0]
  def change
    add_reference :products, :unit, foreign_key: true
  end
end
