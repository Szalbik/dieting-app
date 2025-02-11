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

ActiveRecord::Schema[8.0].define(version: 2025_02_10_235704) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "trackable_type", null: false
    t.bigint "trackable_id", null: false
    t.string "action"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trackable_type", "trackable_id"], name: "index_audit_logs_on_trackable"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "diet_sets", force: :cascade do |t|
    t.string "name"
    t.bigint "diet_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diet_id"], name: "index_diet_sets_on_diet_id"
  end

  create_table "diets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.boolean "active", default: true, null: false
    t.index ["user_id"], name: "index_diets_on_user_id"
  end

  create_table "ingredient_measures", force: :cascade do |t|
    t.float "amount"
    t.string "unit"
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_ingredient_measures_on_product_id"
  end

  create_table "meal_plans", force: :cascade do |t|
    t.bigint "diet_id", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "diet_set_id", null: false
    t.index ["diet_id"], name: "index_meal_plans_on_diet_id"
    t.index ["diet_set_id"], name: "index_meal_plans_on_diet_set_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "state", default: false, null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "unit_id"
    t.integer "diet_set_id"
    t.index ["diet_set_id"], name: "index_products_on_diet_set_id"
    t.index ["unit_id"], name: "index_products_on_unit_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "units", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "diet_sets", "diets"
  add_foreign_key "diets", "users"
  add_foreign_key "ingredient_measures", "products"
  add_foreign_key "meal_plans", "diet_sets"
  add_foreign_key "meal_plans", "diets"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products"
  add_foreign_key "products", "diet_sets"
  add_foreign_key "products", "units"
  add_foreign_key "sessions", "users"
end
