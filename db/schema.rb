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

ActiveRecord::Schema[7.0].define(version: 2026_08_12_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "plpgsql"

  create_table "inventories", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.boolean "personal", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_inventories_on_one_personal_per_owner", unique: true, where: "personal"
    t.index ["owner_id"], name: "index_inventories_on_owner_id"
  end

  create_table "inventory_memberships", force: :cascade do |t|
    t.bigint "inventory_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "editor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_id", "user_id"], name: "index_memberships_on_inventory_and_user", unique: true
    t.index ["inventory_id"], name: "index_inventory_memberships_on_inventory_id"
    t.index ["user_id"], name: "index_inventory_memberships_on_user_id"
  end

  create_table "items", force: :cascade do |t|
    t.integer "quantity"
    t.string "category"
    t.string "tags"
    t.string "current_location"
    t.decimal "weight"
    t.string "owner"
    t.string "intended_location"
    t.text "notes"
    t.text "location_notes"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "Keep"
    t.jsonb "custom_fields", default: {}
    t.bigint "user_id"
    t.bigint "inventory_id", null: false
    t.index ["inventory_id"], name: "index_items_on_inventory_id"
    t.index ["user_id"], name: "index_items_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.datetime "email_verified_at"
    t.string "email_verification_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email_verification_token"], name: "index_users_on_email_verification_token", unique: true
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
  end

  add_foreign_key "inventories", "users", column: "owner_id"
  add_foreign_key "inventory_memberships", "inventories"
  add_foreign_key "inventory_memberships", "users"
  add_foreign_key "items", "inventories"
  add_foreign_key "items", "users"
end
