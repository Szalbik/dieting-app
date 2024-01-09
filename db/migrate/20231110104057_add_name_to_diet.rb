class AddNameToDiet < ActiveRecord::Migration[7.1]
  def change
    add_column :diets, :name, :string
  end
end
