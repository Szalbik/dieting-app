class CreateRecipes < ActiveRecord::Migration[8.0]
  def change
    create_table :recipes do |t|
      t.integer :user_id, null: false
      t.string :name
      t.string :meal_type
      t.text :instructions
      t.integer :kcal
      t.float :protein
      t.float :fat
      t.float :carbs
      t.text :ingredients

      t.timestamps
    end
    add_index :recipes, :user_id
  end
end
