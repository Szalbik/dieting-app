class AddProductCategoryLookupIndexes < ActiveRecord::Migration[8.0]
  def up
    add_index :products,
              'LOWER(TRIM(name))',
              name: 'index_products_on_normalized_name'

    add_index :product_categories,
              :product_id,
              name: 'index_product_categories_on_confirmed_product_id',
              where: 'state = TRUE'
  end

  def down
    remove_index :product_categories, name: 'index_product_categories_on_confirmed_product_id'
    remove_index :products, name: 'index_products_on_normalized_name'
  end
end
