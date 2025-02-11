class CreateMeals < ActiveRecord::Migration[8.0]
  def change
    create_table :meals do |t|
      t.string :name
      t.text :instructions
      t.references :diet_set, null: false, foreign_key: true

      t.timestamps
    end
  end
end
