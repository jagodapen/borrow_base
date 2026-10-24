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

ActiveRecord::Schema[8.1].define(version: 2026_10_23_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "books", force: :cascade do |t|
    t.string "uuid", null: false
    t.string "title", null: false
    t.string "author1_first_name", null: false
    t.string "author1_last_name", null: false
    t.string "author2_first_name"
    t.string "author2_last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uuid"], name: "index_books_on_uuid", unique: true
  end

  create_table "borrowings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.date "borrow_date", null: false
    t.date "due_date", null: false
    t.date "return_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_borrowings_on_due_date"
    t.index ["item_type", "item_id"], name: "index_borrowings_on_active_item", unique: true, where: "(return_date IS NULL)"
    t.index ["item_type", "item_id"], name: "index_borrowings_on_item"
    t.index ["user_id"], name: "index_borrowings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email", null: false
    t.string "card_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_number"], name: "index_users_on_card_number", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "borrowings", "users"
end
