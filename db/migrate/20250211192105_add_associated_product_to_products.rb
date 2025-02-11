class AddAssociatedProductToProducts < ActiveRecord::Migration[8.0]
  def change
    add_reference :products, :associated_product, foreign_key: { to_table: :products }
  end
end