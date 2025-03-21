# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 20_250_224_091_050) do
  create_table 'active_storage_attachments', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'record_type', null: false
    t.bigint 'record_id', null: false
    t.bigint 'blob_id', null: false
    t.datetime 'created_at', null: false
    t.index ['blob_id'], name: 'index_active_storage_attachments_on_blob_id'
    t.index %w[record_type record_id name blob_id], name: 'index_active_storage_attachments_uniqueness',
                                                    unique: true
  end

  create_table 'active_storage_blobs', force: :cascade do |t|
    t.string 'key', null: false
    t.string 'filename', null: false
    t.string 'content_type'
    t.text 'metadata'
    t.string 'service_name', null: false
    t.bigint 'byte_size', null: false
    t.string 'checksum'
    t.datetime 'created_at', null: false
    t.index ['key'], name: 'index_active_storage_blobs_on_key', unique: true
  end

  create_table 'active_storage_variant_records', force: :cascade do |t|
    t.bigint 'blob_id', null: false
    t.string 'variation_digest', null: false
    t.index %w[blob_id variation_digest], name: 'index_active_storage_variant_records_uniqueness', unique: true
  end

  create_table 'audit_logs', force: :cascade do |t|
    t.string 'trackable_type', null: false
    t.integer 'trackable_id', null: false
    t.string 'action'
    t.text 'description'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index %w[trackable_type trackable_id], name: 'index_audit_logs_on_trackable'
  end

  create_table 'categories', force: :cascade do |t|
    t.string 'name'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'diet_set_plans', force: :cascade do |t|
    t.integer 'diet_id', null: false
    t.date 'date', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'diet_set_id', null: false
    t.index ['diet_id'], name: 'index_diet_set_plans_on_diet_id'
    t.index ['diet_set_id'], name: 'index_diet_set_plans_on_diet_set_id'
  end

  create_table 'diet_sets', force: :cascade do |t|
    t.string 'name'
    t.integer 'diet_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['diet_id'], name: 'index_diet_sets_on_diet_id'
  end

  create_table 'diets', force: :cascade do |t|
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'user_id', null: false
    t.string 'name'
    t.boolean 'active', default: true, null: false
    t.index ['user_id'], name: 'index_diets_on_user_id'
  end

  create_table 'ingredient_measures', force: :cascade do |t|
    t.float 'amount'
    t.string 'unit'
    t.integer 'product_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['product_id'], name: 'index_ingredient_measures_on_product_id'
  end

  create_table 'meal_plans', force: :cascade do |t|
    t.integer 'diet_set_plan_id', null: false
    t.integer 'meal_id', null: false
    t.boolean 'selected_for_cart', default: true, null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['diet_set_plan_id'], name: 'index_meal_plans_on_diet_set_plan_id'
    t.index ['meal_id'], name: 'index_meal_plans_on_meal_id'
  end

  create_table 'meals', force: :cascade do |t|
    t.string 'name'
    t.text 'instructions'
    t.integer 'diet_set_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['diet_set_id'], name: 'index_meals_on_diet_set_id'
  end

  create_table 'product_categories', force: :cascade do |t|
    t.integer 'product_id', null: false
    t.integer 'category_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.boolean 'state', default: false, null: false
    t.index ['category_id'], name: 'index_product_categories_on_category_id'
    t.index ['product_id'], name: 'index_product_categories_on_product_id'
  end

  create_table 'products', force: :cascade do |t|
    t.string 'name'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.integer 'unit_id'
    t.integer 'diet_set_id'
    t.integer 'associated_product_id'
    t.integer 'meal_id'
    t.index ['associated_product_id'], name: 'index_products_on_associated_product_id'
    t.index ['diet_set_id'], name: 'index_products_on_diet_set_id'
    t.index ['meal_id'], name: 'index_products_on_meal_id'
    t.index ['unit_id'], name: 'index_products_on_unit_id'
  end

  create_table 'sessions', force: :cascade do |t|
    t.integer 'user_id', null: false
    t.string 'ip_address'
    t.string 'user_agent'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_sessions_on_user_id'
  end

  create_table 'shopping_cart_items', force: :cascade do |t|
    t.integer 'shopping_cart_id', null: false
    t.integer 'product_id', null: false
    t.integer 'quantity'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.date 'date', null: false
    t.datetime 'deleted_at'
    t.integer 'meal_plan_id', null: false
    t.index ['deleted_at'], name: 'index_shopping_cart_items_on_deleted_at'
    t.index ['meal_plan_id'], name: 'index_shopping_cart_items_on_meal_plan_id'
    t.index ['product_id'], name: 'index_shopping_cart_items_on_product_id'
    t.index ['shopping_cart_id'], name: 'index_shopping_cart_items_on_shopping_cart_id'
  end

  create_table 'shopping_carts', force: :cascade do |t|
    t.integer 'user_id', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['user_id'], name: 'index_shopping_carts_on_user_id'
  end

  create_table 'units', force: :cascade do |t|
    t.string 'name'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'users', force: :cascade do |t|
    t.string 'first_name'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'email_address', null: false
    t.string 'password_digest', null: false
    t.boolean 'admin', default: false, null: false
    t.index ['email_address'], name: 'index_users_on_email_address', unique: true
  end

  add_foreign_key 'active_storage_attachments', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'active_storage_variant_records', 'active_storage_blobs', column: 'blob_id'
  add_foreign_key 'diet_set_plans', 'diet_sets'
  add_foreign_key 'diet_set_plans', 'diets'
  add_foreign_key 'diet_sets', 'diets'
  add_foreign_key 'diets', 'users'
  add_foreign_key 'ingredient_measures', 'products'
  add_foreign_key 'meal_plans', 'diet_set_plans'
  add_foreign_key 'meal_plans', 'meals'
  add_foreign_key 'meals', 'diet_sets'
  add_foreign_key 'product_categories', 'categories'
  add_foreign_key 'product_categories', 'products'
  add_foreign_key 'products', 'diet_sets'
  add_foreign_key 'products', 'meals'
  add_foreign_key 'products', 'products', column: 'associated_product_id'
  add_foreign_key 'products', 'units'
  add_foreign_key 'sessions', 'users'
  add_foreign_key 'shopping_cart_items', 'meal_plans'
  add_foreign_key 'shopping_cart_items', 'products'
  add_foreign_key 'shopping_cart_items', 'shopping_carts'
  add_foreign_key 'shopping_carts', 'users'
end
