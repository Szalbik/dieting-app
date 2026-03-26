class CreateMealPlanProductSubstitutions < ActiveRecord::Migration[8.0]
  def change
    create_table :meal_plan_product_substitutions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :meal_plan, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :source_product, null: false
      t.string :replacement_product, null: false
      t.float :source_amount
      t.string :source_unit
      t.float :replacement_amount
      t.string :replacement_unit
      t.float :amount_multiplier
      t.references :replacement_canonical_product, foreign_key: { to_table: :canonical_products }
      t.timestamps
    end

    add_index :meal_plan_product_substitutions,
              [:user_id, :meal_plan_id, :product_id, :replacement_product],
              unique: true,
              name: "index_meal_plan_product_substitutions_on_scope_and_replacement"
  end
end
