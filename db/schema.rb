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

ActiveRecord::Schema[7.2].define(version: 2025_12_26_175832) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "conversation_sessions", force: :cascade do |t|
    t.jsonb "lead_profile", default: {}, null: false
    t.jsonb "discrepancies", default: [], null: false
    t.boolean "needs_human_review", default: false, null: false
    t.integer "qualification_duration_ms"
    t.integer "turns_count", default: 0, null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_conversation_sessions_on_created_at"
    t.index ["lead_profile"], name: "index_conversation_sessions_on_lead_profile", using: :gin
    t.index ["needs_human_review"], name: "index_conversation_sessions_on_needs_human_review"
    t.index ["status"], name: "index_conversation_sessions_on_status"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_session_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.integer "sequence_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_session_id", "sequence_number"], name: "index_messages_on_conversation_session_id_and_sequence_number", unique: true
    t.index ["conversation_session_id"], name: "index_messages_on_conversation_session_id"
    t.index ["created_at"], name: "index_messages_on_created_at"
  end

  create_table "properties", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.decimal "price", precision: 12, scale: 2, null: false
    t.string "city", null: false
    t.string "area"
    t.integer "bedrooms"
    t.integer "bathrooms"
    t.decimal "square_meters", precision: 8, scale: 2
    t.string "property_type"
    t.jsonb "features", default: {}
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_properties_on_active"
    t.index ["bedrooms"], name: "index_properties_on_bedrooms"
    t.index ["city", "active"], name: "index_properties_on_city_and_active"
    t.index ["city"], name: "index_properties_on_city"
    t.index ["price"], name: "index_properties_on_price"
  end

  add_foreign_key "messages", "conversation_sessions"
end
