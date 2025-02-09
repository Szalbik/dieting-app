class CreateMealPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_plans do |t|
      t.references :diet, null: false, foreign_key: true
      t.date :date, null: false

      t.timestamps
    end
  end
end
