class AllowDietSetIdToBeNil < ActiveRecord::Migration[7.1]
  def change
    change_column :products, :diet_set_id, :integer, null: true
  end
end
