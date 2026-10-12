# frozen_string_literal: true

# SQLite drops a column by rebuilding the table, and dropping the old products
# table fires ON DELETE CASCADE on product_categories and ingredient_measures.
# Rails' own PRAGMA foreign_keys = OFF runs inside a transaction, where SQLite
# ignores it, so turn FKs off here — outside any transaction. Without a DDL
# transaction the steps are independent, so each one is guarded for a rerun.
class DropUnitsAndDeadProductColumns < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    without_foreign_keys do
      # One rebuild per column: SQLite's remove_column also drops the column's FK and
      # index, so there is no half-done state between "FK gone" and "column gone".
      remove_column :products, :associated_product_id if column_exists?(:products, :associated_product_id)
      remove_column :products, :unit_id if column_exists?(:products, :unit_id)
      drop_table :units if table_exists?(:units)
    end
  end

  def down
    without_foreign_keys do
      create_units_table unless table_exists?(:units)
      unless column_exists?(:products, :unit_id)
        add_reference :products, :unit, type: :integer, index: true, foreign_key: true
      end
      unless column_exists?(:products, :associated_product_id)
        add_reference :products, :associated_product, type: :integer, index: true,
                                                      foreign_key: { to_table: :products }
      end
    end
  end

  private

  def create_units_table
    create_table :units do |t|
      t.string :name
      t.timestamps
    end
  end

  def without_foreign_keys
    execute 'PRAGMA foreign_keys = OFF'
    yield
  ensure
    execute 'PRAGMA foreign_keys = ON'
  end
end
