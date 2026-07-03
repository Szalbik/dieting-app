class AddStatusToDiets < ActiveRecord::Migration[8.0]
  def change
    add_column :diets, :status, :string, default: 'ready', null: false
    add_column :diets, :generation_error, :text
  end
end
