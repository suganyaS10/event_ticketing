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

ActiveRecord::Schema[8.1].define(version: 2026_08_08_110706) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "event_status", ["draft", "published"]
  create_enum "order_status", ["initialised", "succeeded", "failed", "cancelled"]

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "mobile"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_customers_on_email", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "end_time"
    t.string "name", null: false
    t.string "short_description"
    t.datetime "start_time", null: false
    t.enum "status", default: "draft", null: false, enum_type: "event_status"
    t.datetime "updated_at", null: false
    t.string "venue", null: false
    t.index ["status", "start_time"], name: "index_events_on_status_and_start_time"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.integer "quantity", null: false
    t.bigint "ticket_tier_id", null: false
    t.integer "total_cents", default: 0, null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["ticket_tier_id"], name: "index_order_items_on_ticket_tier_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "event_id", null: false
    t.text "failure_reason"
    t.string "order_ref", null: false
    t.enum "status", default: "initialised", null: false, enum_type: "order_status"
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["event_id"], name: "index_orders_on_event_id"
    t.index ["order_ref"], name: "index_orders_on_order_ref", unique: true
  end

  create_table "ticket_tiers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "GBP", null: false
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.text "perks"
    t.integer "price_cents", null: false
    t.integer "quantity_sold", default: 0, null: false
    t.integer "quantity_total", null: false
    t.datetime "sale_ends_at"
    t.datetime "sale_starts_at"
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_ticket_tiers_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_ticket_tiers_on_event_id"
    t.check_constraint "quantity_sold >= 0 AND quantity_sold <= quantity_total", name: "ticket_inventory_within_capacity"
  end

  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "ticket_tiers"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "events"
  add_foreign_key "ticket_tiers", "events"
end
