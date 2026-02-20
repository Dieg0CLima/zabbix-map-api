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

ActiveRecord::Schema[8.0].define(version: 2026_02_18_190851) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "map_nodes", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.string "label", null: false
    t.string "node_kind", null: false
    t.decimal "x", precision: 10, scale: 2, null: false
    t.decimal "y", precision: 10, scale: 2, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "zabbix_ref"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_map_id", "node_kind"], name: "index_map_nodes_on_network_map_id_and_node_kind"
    t.index ["network_map_id", "zabbix_ref"], name: "index_map_nodes_on_network_map_id_and_zabbix_ref"
    t.index ["network_map_id"], name: "index_map_nodes_on_network_map_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "admin", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "user_id"], name: "index_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "role"], name: "index_memberships_on_user_id_and_role"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "network_cable_points", force: :cascade do |t|
    t.bigint "network_cable_id", null: false
    t.integer "position", null: false
    t.decimal "x", precision: 10, scale: 2, null: false
    t.decimal "y", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_cable_id", "position"], name: "index_network_cable_points_on_network_cable_id_and_position", unique: true
    t.index ["network_cable_id"], name: "index_network_cable_points_on_network_cable_id"
  end

  create_table "network_cables", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.bigint "source_node_id", null: false
    t.bigint "target_node_id", null: false
    t.string "label"
    t.string "cable_type", default: "logical", null: false
    t.string "status", default: "unknown", null: false
    t.integer "bandwidth_mbps"
    t.decimal "length_meters", precision: 10, scale: 2
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_map_id", "source_node_id", "target_node_id"], name: "index_network_cables_on_map_source_target", unique: true
    t.index ["network_map_id"], name: "index_network_cables_on_network_map_id"
    t.index ["source_node_id"], name: "index_network_cables_on_source_node_id"
    t.index ["target_node_id"], name: "index_network_cables_on_target_node_id"
    t.check_constraint "source_node_id <> target_node_id", name: "network_cables_source_target_diff"
  end

  create_table "network_maps", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "source_type", default: "manual", null: false
    t.string "zabbix_mapid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "zabbix_connection_id"
    t.index ["organization_id", "name"], name: "index_network_maps_on_organization_id_and_name", unique: true
    t.index ["organization_id", "zabbix_mapid"], name: "index_network_maps_on_organization_id_and_zabbix_mapid", unique: true
    t.index ["organization_id"], name: "index_network_maps_on_organization_id"
    t.index ["zabbix_connection_id"], name: "index_network_maps_on_zabbix_connection_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.boolean "admin", default: false, null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "zabbix_connections", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "base_url"
    t.text "api_token_ciphertext"
    t.string "status", default: "active", null: false
    t.boolean "default_connection", default: false, null: false
    t.datetime "last_synced_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "connection_mode", default: "api", null: false
    t.string "db_adapter"
    t.string "db_host"
    t.integer "db_port"
    t.string "db_name"
    t.string "db_username"
    t.text "db_password"
    t.index ["organization_id", "connection_mode"], name: "idx_on_organization_id_connection_mode_c2700c34f1"
    t.index ["organization_id", "default_connection"], name: "index_zabbix_connections_on_org_default_true", unique: true, where: "(default_connection = true)"
    t.index ["organization_id", "name"], name: "index_zabbix_connections_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_zabbix_connections_on_organization_id"
  end

  create_table "zabbix_hosts", force: :cascade do |t|
    t.bigint "zabbix_connection_id", null: false
    t.string "hostid", null: false
    t.string "name", null: false
    t.string "status"
    t.string "available"
    t.jsonb "interfaces", default: [], null: false
    t.jsonb "tags", default: [], null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["zabbix_connection_id", "hostid"], name: "index_zabbix_hosts_on_zabbix_connection_id_and_hostid", unique: true
    t.index ["zabbix_connection_id", "name"], name: "index_zabbix_hosts_on_zabbix_connection_id_and_name"
    t.index ["zabbix_connection_id"], name: "index_zabbix_hosts_on_zabbix_connection_id"
  end

  create_table "zabbix_items", force: :cascade do |t|
    t.bigint "zabbix_connection_id", null: false
    t.bigint "zabbix_host_id"
    t.string "itemid", null: false
    t.string "name", null: false
    t.string "key_", null: false
    t.string "value_type"
    t.string "units"
    t.string "status"
    t.string "state"
    t.text "lastvalue"
    t.datetime "lastclock"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["zabbix_connection_id", "itemid"], name: "index_zabbix_items_on_zabbix_connection_id_and_itemid", unique: true
    t.index ["zabbix_connection_id", "key_"], name: "index_zabbix_items_on_zabbix_connection_id_and_key_"
    t.index ["zabbix_connection_id", "zabbix_host_id"], name: "index_zabbix_items_on_zabbix_connection_id_and_zabbix_host_id"
    t.index ["zabbix_connection_id"], name: "index_zabbix_items_on_zabbix_connection_id"
    t.index ["zabbix_host_id"], name: "index_zabbix_items_on_zabbix_host_id"
  end

  add_foreign_key "map_nodes", "network_maps"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "network_cable_points", "network_cables"
  add_foreign_key "network_cables", "map_nodes", column: "source_node_id"
  add_foreign_key "network_cables", "map_nodes", column: "target_node_id"
  add_foreign_key "network_cables", "network_maps"
  add_foreign_key "network_maps", "organizations"
  add_foreign_key "network_maps", "zabbix_connections"
  add_foreign_key "zabbix_connections", "organizations"
  add_foreign_key "zabbix_hosts", "zabbix_connections"
  add_foreign_key "zabbix_items", "zabbix_connections"
  add_foreign_key "zabbix_items", "zabbix_hosts"
end
