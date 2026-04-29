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

ActiveRecord::Schema[8.0].define(version: 2026_04_20_100001) do
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
    t.integer "trackable_id", null: false
    t.string "action"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trackable_type", "trackable_id"], name: "index_audit_logs_on_trackable"
  end

  create_table "canonical_product_aliases", force: :cascade do |t|
    t.integer "canonical_product_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "stem_signature", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_product_id", "name"], name: "idx_canonical_aliases_on_product_and_name", unique: true
    t.index ["canonical_product_id"], name: "index_canonical_product_aliases_on_canonical_product_id"
    t.index ["normalized_name"], name: "index_canonical_product_aliases_on_normalized_name"
    t.index ["stem_signature"], name: "index_canonical_product_aliases_on_stem_signature"
  end

  create_table "canonical_products", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_canonical_products_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_canonical_products_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "custom_cart_items", force: :cascade do |t|
    t.integer "shopping_cart_id", null: false
    t.string "name", null: false
    t.integer "quantity", default: 1, null: false
    t.string "unit", default: "szt"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shopping_cart_id", "name"], name: "index_custom_cart_items_on_shopping_cart_id_and_name"
    t.index ["shopping_cart_id"], name: "index_custom_cart_items_on_shopping_cart_id"
  end

  create_table "diet_set_plans", force: :cascade do |t|
    t.integer "diet_id", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "diet_set_id", null: false
    t.boolean "shopping_done", default: false, null: false
    t.index ["diet_id"], name: "index_diet_set_plans_on_diet_id"
    t.index ["diet_set_id"], name: "index_diet_set_plans_on_diet_set_id"
  end

  create_table "diet_sets", force: :cascade do |t|
    t.string "name"
    t.integer "diet_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diet_id"], name: "index_diet_sets_on_diet_id"
  end

  create_table "dietitian_waitlist_entries", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "email_address", null: false
    t.string "company_name", null: false
    t.integer "status", default: 0, null: false
    t.text "notes"
    t.datetime "demo_called_at"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_dietitian_waitlist_entries_on_created_at"
    t.index ["email_address"], name: "index_dietitian_waitlist_entries_on_email_address", unique: true
    t.index ["status"], name: "index_dietitian_waitlist_entries_on_status"
  end

  create_table "diets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "name"
    t.boolean "active", default: true, null: false
    t.text "parsed_json"
    t.integer "meals_per_day"
    t.index ["user_id"], name: "index_diets_on_user_id"
  end

  create_table "ingredient_measures", force: :cascade do |t|
    t.float "amount"
    t.string "unit"
    t.integer "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_ingredient_measures_on_product_id"
  end

  create_table "meal_plan_product_substitutions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "meal_plan_id", null: false
    t.integer "product_id", null: false
    t.string "source_product", null: false
    t.string "replacement_product", null: false
    t.float "source_amount"
    t.string "source_unit"
    t.float "replacement_amount"
    t.string "replacement_unit"
    t.float "amount_multiplier"
    t.integer "replacement_canonical_product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meal_plan_id"], name: "index_meal_plan_product_substitutions_on_meal_plan_id"
    t.index ["product_id"], name: "index_meal_plan_product_substitutions_on_product_id"
    t.index ["replacement_canonical_product_id"], name: "idx_on_replacement_canonical_product_id_3c28a877f7"
    t.index ["user_id", "meal_plan_id", "product_id", "replacement_product"], name: "index_meal_plan_product_substitutions_on_scope_and_replacement", unique: true
    t.index ["user_id"], name: "index_meal_plan_product_substitutions_on_user_id"
  end

  create_table "meal_plans", force: :cascade do |t|
    t.integer "diet_set_plan_id", null: false
    t.integer "meal_id", null: false
    t.boolean "selected_for_cart", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["diet_set_plan_id"], name: "index_meal_plans_on_diet_set_plan_id"
    t.index ["meal_id"], name: "index_meal_plans_on_meal_id"
  end

  create_table "meals", force: :cascade do |t|
    t.string "name"
    t.text "instructions"
    t.integer "diet_set_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "meal_type"
    t.integer "kcal"
    t.float "protein"
    t.float "fat"
    t.float "carbs"
    t.index ["diet_set_id"], name: "index_meals_on_diet_set_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "state", default: false, null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id"], name: "index_product_categories_on_confirmed_product_id", where: "state = TRUE"
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "product_name_suggestions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "raw_name", null: false
    t.integer "canonical_product_id"
    t.float "confidence", default: 0.0, null: false
    t.string "match_type", null: false
    t.string "source", null: false
    t.string "status", default: "pending", null: false
    t.integer "occurrence_count", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_product_id"], name: "index_product_name_suggestions_on_canonical_product_id"
    t.index ["status"], name: "index_product_name_suggestions_on_status"
    t.index ["user_id", "raw_name"], name: "idx_pns_unique_pending_per_user_raw_name", unique: true, where: "status = 'pending'"
    t.index ["user_id"], name: "index_product_name_suggestions_on_user_id"
  end

  create_table "product_substitutions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "source_product", null: false
    t.string "replacement_product", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "source_amount"
    t.string "source_unit"
    t.float "replacement_amount"
    t.string "replacement_unit"
    t.float "amount_multiplier"
    t.integer "source_canonical_product_id"
    t.integer "replacement_canonical_product_id"
    t.index ["replacement_canonical_product_id"], name: "idx_on_replacement_canonical_product_id_77fe11f052"
    t.index ["source_canonical_product_id"], name: "index_product_substitutions_on_source_canonical_product_id"
    t.index ["user_id", "source_product", "replacement_product"], name: "index_product_substitutions_on_user_and_pair", unique: true
    t.index ["user_id"], name: "index_product_substitutions_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "unit_id"
    t.integer "diet_set_id"
    t.integer "associated_product_id"
    t.integer "meal_id"
    t.string "base_product_name"
    t.integer "canonical_product_id"
    t.integer "base_canonical_product_id"
    t.string "original_name"
    t.index "LOWER(TRIM(name))", name: "index_products_on_normalized_name"
    t.index ["associated_product_id"], name: "index_products_on_associated_product_id"
    t.index ["base_canonical_product_id"], name: "index_products_on_base_canonical_product_id"
    t.index ["canonical_product_id"], name: "index_products_on_canonical_product_id"
    t.index ["diet_set_id"], name: "index_products_on_diet_set_id"
    t.index ["meal_id"], name: "index_products_on_meal_id"
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

  create_table "shopping_cart_invitations", force: :cascade do |t|
    t.integer "inviter_id", null: false
    t.integer "invitee_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "accepted_at"
    t.datetime "responded_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invitee_id"], name: "index_shopping_cart_invitations_on_invitee_id"
    t.index ["inviter_id", "invitee_id", "status"], name: "idx_cart_invites_on_pair_and_status"
    t.index ["inviter_id"], name: "index_shopping_cart_invitations_on_inviter_id"
    t.index ["status"], name: "index_shopping_cart_invitations_on_status"
  end

  create_table "shopping_cart_items", force: :cascade do |t|
    t.integer "shopping_cart_id", null: false
    t.integer "product_id", null: false
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "date", null: false
    t.datetime "deleted_at"
    t.integer "meal_plan_id", null: false
    t.index ["deleted_at"], name: "index_shopping_cart_items_on_deleted_at"
    t.index ["meal_plan_id"], name: "index_shopping_cart_items_on_meal_plan_id"
    t.index ["product_id"], name: "index_shopping_cart_items_on_product_id"
    t.index ["shopping_cart_id"], name: "index_shopping_cart_items_on_shopping_cart_id"
  end

  create_table "shopping_carts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_shopping_carts_on_user_id", unique: true
  end

  create_table "substitution_product_matches", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "source_product", null: false
    t.string "matched_product_name", null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "source_product", "matched_product_name"], name: "index_substitution_product_matches_on_user_source_and_match", unique: true
    t.index ["user_id"], name: "index_substitution_product_matches_on_user_id"
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
    t.integer "active_shopping_cart_id"
    t.index ["active_shopping_cart_id"], name: "index_users_on_active_shopping_cart_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "canonical_product_aliases", "canonical_products"
  add_foreign_key "canonical_products", "users"
  add_foreign_key "custom_cart_items", "shopping_carts"
  add_foreign_key "diet_set_plans", "diet_sets"
  add_foreign_key "diet_set_plans", "diets"
  add_foreign_key "diet_sets", "diets"
  add_foreign_key "diets", "users"
  add_foreign_key "ingredient_measures", "products", on_delete: :cascade
  add_foreign_key "meal_plan_product_substitutions", "canonical_products", column: "replacement_canonical_product_id"
  add_foreign_key "meal_plan_product_substitutions", "meal_plans"
  add_foreign_key "meal_plan_product_substitutions", "products"
  add_foreign_key "meal_plan_product_substitutions", "users"
  add_foreign_key "meal_plans", "diet_set_plans"
  add_foreign_key "meal_plans", "meals", on_delete: :cascade
  add_foreign_key "meals", "diet_sets"
  add_foreign_key "product_categories", "categories", on_delete: :cascade
  add_foreign_key "product_categories", "products", on_delete: :cascade
  add_foreign_key "product_substitutions", "canonical_products", column: "replacement_canonical_product_id"
  add_foreign_key "product_substitutions", "canonical_products", column: "source_canonical_product_id"
  add_foreign_key "product_substitutions", "users"
  add_foreign_key "products", "canonical_products"
  add_foreign_key "products", "canonical_products", column: "base_canonical_product_id"
  add_foreign_key "products", "diet_sets"
  add_foreign_key "products", "meals", on_delete: :nullify
  add_foreign_key "products", "products", column: "associated_product_id"
  add_foreign_key "products", "units"
  add_foreign_key "sessions", "users"
  add_foreign_key "shopping_cart_invitations", "users", column: "invitee_id"
  add_foreign_key "shopping_cart_invitations", "users", column: "inviter_id"
  add_foreign_key "shopping_cart_items", "meal_plans", on_delete: :cascade
  add_foreign_key "shopping_cart_items", "products"
  add_foreign_key "shopping_cart_items", "shopping_carts"
  add_foreign_key "shopping_carts", "users"
  add_foreign_key "substitution_product_matches", "users"
  add_foreign_key "users", "shopping_carts", column: "active_shopping_cart_id"
end
