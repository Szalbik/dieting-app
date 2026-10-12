# frozen_string_literal: true

# SQLite drops a column by rebuilding the table, and dropping the old products
# table fires ON DELETE CASCADE on product_categories and ingredient_measures.
# Rails' own PRAGMA foreign_keys = OFF runs inside a transaction, where SQLite
# ignores it, so turn FKs off here — outside any transaction.
class DropUnitsAndDeadProductColumns < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    without_foreign_keys do
      remove_reference :products, :associated_product, type: :integer, index: true,
                                                       foreign_key: { to_table: :products }
      remove_reference :products, :unit, type: :integer, index: true, foreign_key: true
      drop_table :units
    end
  end

  def down
    without_foreign_keys do
      create_table :units do |t|
        t.string :name
        t.timestamps
      end
      add_reference :products, :unit, type: :integer, index: true, foreign_key: true
      add_reference :products, :associated_product, type: :integer, index: true,
                                                    foreign_key: { to_table: :products }
    end
  end

  private

  def without_foreign_keys
    execute 'PRAGMA foreign_keys = OFF'
    yield
  ensure
    execute 'PRAGMA foreign_keys = ON'
  end
end
