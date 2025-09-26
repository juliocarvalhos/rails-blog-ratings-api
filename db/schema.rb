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

ActiveRecord::Schema[8.0].define(version: 2025_09_26_010839) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "posts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.inet "ip", null: false
    t.decimal "avg_rating", precision: 3, scale: 2, default: "0.0"
    t.integer "ratings_count", default: 0, null: false
    t.integer "ratings_sum", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "(\nCASE\n    WHEN (ratings_count > 0) THEN ((ratings_sum)::double precision / (ratings_count)::double precision)\n    ELSE (0)::double precision\nEND)", name: "index_posts_on_calculated_avg_rating"
    t.index ["avg_rating"], name: "index_posts_on_avg_rating"
    t.index ["created_at"], name: "index_posts_on_created_at"
    t.index ["ip", "user_id"], name: "index_posts_ip_user"
    t.index ["ip"], name: "index_posts_on_ip"
    t.index ["user_id", "avg_rating"], name: "index_posts_user_rating"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "ratings", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.integer "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ratings_on_created_at"
    t.index ["post_id"], name: "index_ratings_on_post_id"
    t.index ["user_id", "post_id"], name: "index_ratings_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_ratings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "login", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["login"], name: "index_users_on_login", unique: true
  end

  add_foreign_key "posts", "users"
  add_foreign_key "ratings", "posts"
  add_foreign_key "ratings", "users"
end
