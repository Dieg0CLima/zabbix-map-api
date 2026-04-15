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

ActiveRecord::Schema[8.0].define(version: 2026_04_11_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "device_interfaces", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.string "name", null: false
    t.string "interface_type"
    t.string "description"
    t.boolean "enabled", default: true, null: false
    t.boolean "management", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id", "name"], name: "index_device_interfaces_on_device_id_and_name", unique: true
    t.index ["device_id"], name: "index_device_interfaces_on_device_id"
  end

  create_table "device_monitoring_items", force: :cascade do |t|
    t.bigint "device_monitoring_profile_id", null: false
    t.bigint "zabbix_item_id", null: false
    t.string "alias"
    t.string "category"
    t.string "subcategory"
    t.string "usage", default: "map", null: false
    t.integer "display_priority", default: 0, null: false
    t.boolean "map_visibility", default: false, null: false
    t.boolean "is_primary_metric", default: false, null: false
    t.boolean "is_health_metric", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_monitoring_profile_id", "zabbix_item_id"], name: "index_device_monitoring_items_on_profile_and_item", unique: true
    t.index ["device_monitoring_profile_id"], name: "index_device_monitoring_items_on_device_monitoring_profile_id"
    t.index ["zabbix_item_id"], name: "index_device_monitoring_items_on_zabbix_item_id"
  end

  create_table "device_monitoring_profiles", force: :cascade do |t|
    t.bigint "device_id", null: false
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_id"], name: "index_device_monitoring_profiles_on_device_id"
  end

  create_table "devices", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "site_id"
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "device_type", default: "other", null: false
    t.string "zabbix_ref"
    t.string "status", default: "planned", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "zabbix_host_id"
    t.string "hostname"
    t.string "role", default: "generic", null: false
    t.string "vendor"
    t.string "model"
    t.string "serial_number"
    t.string "management_ip"
    t.index ["organization_id", "external_id"], name: "index_devices_on_organization_id_and_external_id", unique: true
    t.index ["organization_id", "hostname"], name: "index_devices_on_organization_id_and_hostname"
    t.index ["organization_id", "name"], name: "index_devices_on_organization_id_and_name"
    t.index ["organization_id", "serial_number"], name: "index_devices_on_organization_id_and_serial_number"
    t.index ["organization_id", "zabbix_ref"], name: "index_devices_on_organization_id_and_zabbix_ref"
    t.index ["organization_id"], name: "index_devices_on_organization_id"
    t.index ["site_id"], name: "index_devices_on_site_id"
    t.index ["zabbix_host_id"], name: "index_devices_on_zabbix_host_id"
  end

  create_table "map_edges", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.bigint "source_node_id", null: false
    t.bigint "target_node_id", null: false
    t.string "edge_type", default: "logical", null: false
    t.string "label"
    t.string "color"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_map_id", "source_node_id", "target_node_id", "edge_type"], name: "idx_map_edges_uniqueness", unique: true
    t.index ["network_map_id"], name: "index_map_edges_on_network_map_id"
    t.index ["source_node_id"], name: "index_map_edges_on_source_node_id"
    t.index ["target_node_id"], name: "index_map_edges_on_target_node_id"
  end

  create_table "map_element_items", force: :cascade do |t|
    t.bigint "map_element_id", null: false
    t.bigint "zabbix_item_id", null: false
    t.string "alias"
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["map_element_id", "zabbix_item_id"], name: "index_map_element_items_on_element_and_item", unique: true
    t.index ["map_element_id"], name: "index_map_element_items_on_map_element_id"
    t.index ["zabbix_item_id"], name: "index_map_element_items_on_zabbix_item_id"
  end

  create_table "map_elements", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.string "mappable_type", null: false
    t.bigint "mappable_id", null: false
    t.string "external_id", null: false
    t.decimal "lat", precision: 10, scale: 6, null: false
    t.decimal "lng", precision: 10, scale: 6, null: false
    t.string "icon_override"
    t.string "color_override"
    t.string "label_override"
    t.integer "size_override"
    t.boolean "collapsed", default: false, null: false
    t.integer "display_order", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mappable_type", "mappable_id"], name: "index_map_elements_on_mappable"
    t.index ["mappable_type", "mappable_id"], name: "index_map_elements_on_mappable_type_and_mappable_id"
    t.index ["network_map_id", "external_id"], name: "index_map_elements_on_network_map_id_and_external_id", unique: true
    t.index ["network_map_id", "mappable_type", "mappable_id"], name: "index_map_elements_on_map_and_mappable", unique: true
    t.index ["network_map_id"], name: "index_map_elements_on_network_map_id"
  end

  create_table "map_monitoring_bindings", force: :cascade do |t|
    t.bigint "map_node_id", null: false
    t.bigint "zabbix_link_id"
    t.string "metric_type", null: false
    t.string "display_mode", default: "badge", null: false
    t.string "label"
    t.string "severity_source"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["map_node_id"], name: "index_map_monitoring_bindings_on_map_node_id"
    t.index ["zabbix_link_id"], name: "index_map_monitoring_bindings_on_zabbix_link_id"
  end

  create_table "map_node_items", force: :cascade do |t|
    t.bigint "map_node_id", null: false
    t.bigint "zabbix_item_id", null: false
    t.string "alias"
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["map_node_id", "zabbix_item_id"], name: "index_map_node_items_on_node_and_item", unique: true
    t.index ["map_node_id"], name: "index_map_node_items_on_map_node_id"
    t.index ["zabbix_item_id"], name: "index_map_node_items_on_zabbix_item_id"
  end

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
    t.string "external_id", null: false
    t.string "icon", null: false
    t.string "color", null: false
    t.integer "size", null: false
    t.decimal "lat", precision: 10, scale: 6, null: false
    t.decimal "lng", precision: 10, scale: 6, null: false
    t.bigint "map_pop_id"
    t.bigint "device_id"
    t.bigint "zabbix_host_id"
    t.string "hostname"
    t.string "ip_address"
    t.text "description"
    t.string "mappable_type"
    t.bigint "mappable_id"
    t.integer "width"
    t.integer "height"
    t.string "label_override"
    t.boolean "visible", default: true, null: false
    t.boolean "collapsed", default: false, null: false
    t.index ["device_id"], name: "index_map_nodes_on_device_id"
    t.index ["map_pop_id"], name: "index_map_nodes_on_map_pop_id"
    t.index ["mappable_type", "mappable_id"], name: "index_map_nodes_on_mappable_type_and_mappable_id"
    t.index ["network_map_id", "external_id"], name: "index_map_nodes_on_network_map_id_and_external_id", unique: true
    t.index ["network_map_id", "node_kind"], name: "index_map_nodes_on_network_map_id_and_node_kind"
    t.index ["network_map_id", "zabbix_ref"], name: "index_map_nodes_on_network_map_id_and_zabbix_ref"
    t.index ["network_map_id"], name: "index_map_nodes_on_network_map_id"
    t.index ["zabbix_host_id"], name: "index_map_nodes_on_zabbix_host_id"
  end

  create_table "map_pops", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.string "name", null: false
    t.string "external_id", null: false
    t.decimal "lat", precision: 10, scale: 6, null: false
    t.decimal "lng", precision: 10, scale: 6, null: false
    t.string "color", default: "#7c3aed", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "site_id"
    t.index ["network_map_id", "external_id"], name: "index_map_pops_on_network_map_id_and_external_id", unique: true
    t.index ["network_map_id", "name"], name: "index_map_pops_on_network_map_id_and_name"
    t.index ["network_map_id"], name: "index_map_pops_on_network_map_id"
    t.index ["site_id"], name: "index_map_pops_on_site_id"
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

  create_table "network_cable_events", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.bigint "network_cable_id"
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.string "actor"
    t.jsonb "before_state", default: {}, null: false
    t.jsonb "after_state", default: {}, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_cable_id", "occurred_at"], name: "index_network_cable_events_on_network_cable_id_and_occurred_at"
    t.index ["network_cable_id"], name: "index_network_cable_events_on_network_cable_id"
    t.index ["network_map_id", "occurred_at"], name: "index_network_cable_events_on_network_map_id_and_occurred_at"
    t.index ["network_map_id"], name: "index_network_cable_events_on_network_map_id"
  end

  create_table "network_cable_items", force: :cascade do |t|
    t.bigint "network_cable_id", null: false
    t.bigint "zabbix_item_id", null: false
    t.string "alias"
    t.string "metric_role", default: "bandwidth_in", null: false
    t.integer "display_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_cable_id", "zabbix_item_id"], name: "index_network_cable_items_on_cable_and_item", unique: true
    t.index ["network_cable_id"], name: "index_network_cable_items_on_network_cable_id"
    t.index ["zabbix_item_id"], name: "index_network_cable_items_on_zabbix_item_id"
  end

  create_table "network_cable_points", force: :cascade do |t|
    t.bigint "network_cable_id", null: false
    t.integer "position", null: false
    t.decimal "x", precision: 12, scale: 6, null: false
    t.decimal "y", precision: 12, scale: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_cable_id", "position"], name: "index_network_cable_points_on_network_cable_id_and_position", unique: true
    t.index ["network_cable_id"], name: "index_network_cable_points_on_network_cable_id"
  end

  create_table "network_cables", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.bigint "source_node_id"
    t.bigint "target_node_id"
    t.string "label"
    t.string "cable_type", default: "logical", null: false
    t.string "status", default: "unknown", null: false
    t.integer "bandwidth_mbps"
    t.decimal "length_meters", precision: 10, scale: 2
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id", null: false
    t.string "color", null: false
    t.integer "weight", null: false
    t.string "pattern", default: "solid", null: false
    t.bigint "source_pop_id"
    t.bigint "target_pop_id"
    t.bigint "network_link_id"
    t.bigint "source_element_id"
    t.bigint "target_element_id"
    t.index ["network_link_id"], name: "index_network_cables_on_network_link_id"
    t.index ["network_map_id", "external_id"], name: "index_network_cables_on_network_map_id_and_external_id", unique: true
    t.index ["network_map_id"], name: "index_network_cables_on_network_map_id"
    t.index ["source_element_id"], name: "index_network_cables_on_source_element_id"
    t.index ["source_node_id"], name: "index_network_cables_on_source_node_id"
    t.index ["source_pop_id"], name: "index_network_cables_on_source_pop_id"
    t.index ["target_element_id"], name: "index_network_cables_on_target_element_id"
    t.index ["target_node_id"], name: "index_network_cables_on_target_node_id"
    t.index ["target_pop_id"], name: "index_network_cables_on_target_pop_id"
  end

  create_table "network_links", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "external_id", null: false
    t.string "label"
    t.bigint "source_device_id"
    t.bigint "target_device_id"
    t.bigint "source_site_id"
    t.bigint "target_site_id"
    t.string "link_type", default: "logical", null: false
    t.integer "bandwidth_mbps"
    t.string "status", default: "planned", null: false
    t.string "zabbix_item_ref"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "external_id"], name: "index_network_links_on_organization_id_and_external_id", unique: true
    t.index ["organization_id", "zabbix_item_ref"], name: "index_network_links_on_organization_id_and_zabbix_item_ref"
    t.index ["organization_id"], name: "index_network_links_on_organization_id"
    t.index ["source_device_id"], name: "index_network_links_on_source_device_id"
    t.index ["source_site_id"], name: "index_network_links_on_source_site_id"
    t.index ["target_device_id"], name: "index_network_links_on_target_device_id"
    t.index ["target_site_id"], name: "index_network_links_on_target_site_id"
  end

  create_table "network_map_snapshots", force: :cascade do |t|
    t.bigint "network_map_id", null: false
    t.string "label", null: false
    t.jsonb "state", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["network_map_id", "created_at"], name: "index_network_map_snapshots_on_network_map_id_and_created_at"
    t.index ["network_map_id"], name: "index_network_map_snapshots_on_network_map_id"
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
    t.string "active_base_layer", default: "standard", null: false
    t.jsonb "metadata", default: {}, null: false
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

  create_table "sites", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "address"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.string "status", default: "active", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.text "description"
    t.string "city"
    t.string "state"
    t.index ["organization_id", "external_id"], name: "index_sites_on_organization_id_and_external_id", unique: true
    t.index ["organization_id", "name"], name: "index_sites_on_organization_id_and_name", unique: true
    t.index ["organization_id", "slug"], name: "index_sites_on_organization_id_and_slug", unique: true
    t.index ["organization_id", "status"], name: "index_sites_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_sites_on_organization_id"
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

  create_table "zabbix_links", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "zabbix_connection_id", null: false
    t.string "linkable_type", null: false
    t.bigint "linkable_id", null: false
    t.string "resource_type", null: false
    t.string "external_id", null: false
    t.string "external_key"
    t.string "name"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["linkable_type", "linkable_id", "resource_type"], name: "idx_unique_device_host_zabbix_links", unique: true, where: "(((linkable_type)::text = 'Device'::text) AND ((resource_type)::text = 'host'::text))"
    t.index ["linkable_type", "linkable_id"], name: "index_zabbix_links_on_linkable_type_and_linkable_id"
    t.index ["organization_id", "zabbix_connection_id", "resource_type", "external_id"], name: "idx_zabbix_links_external_uniqueness", unique: true
    t.index ["organization_id"], name: "index_zabbix_links_on_organization_id"
    t.index ["zabbix_connection_id"], name: "index_zabbix_links_on_zabbix_connection_id"
  end

  add_foreign_key "device_interfaces", "devices"
  add_foreign_key "device_monitoring_items", "device_monitoring_profiles"
  add_foreign_key "device_monitoring_items", "zabbix_items"
  add_foreign_key "device_monitoring_profiles", "devices"
  add_foreign_key "devices", "organizations"
  add_foreign_key "devices", "sites"
  add_foreign_key "devices", "zabbix_hosts", on_delete: :nullify
  add_foreign_key "map_edges", "map_nodes", column: "source_node_id"
  add_foreign_key "map_edges", "map_nodes", column: "target_node_id"
  add_foreign_key "map_edges", "network_maps"
  add_foreign_key "map_element_items", "map_elements"
  add_foreign_key "map_element_items", "zabbix_items"
  add_foreign_key "map_elements", "network_maps"
  add_foreign_key "map_monitoring_bindings", "map_nodes"
  add_foreign_key "map_monitoring_bindings", "zabbix_links"
  add_foreign_key "map_node_items", "map_nodes"
  add_foreign_key "map_node_items", "zabbix_items"
  add_foreign_key "map_nodes", "devices"
  add_foreign_key "map_nodes", "map_pops"
  add_foreign_key "map_nodes", "network_maps"
  add_foreign_key "map_nodes", "zabbix_hosts", on_delete: :nullify
  add_foreign_key "map_pops", "network_maps"
  add_foreign_key "map_pops", "sites"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "network_cable_events", "network_cables"
  add_foreign_key "network_cable_events", "network_maps"
  add_foreign_key "network_cable_items", "network_cables"
  add_foreign_key "network_cable_items", "zabbix_items"
  add_foreign_key "network_cable_points", "network_cables"
  add_foreign_key "network_cables", "map_elements", column: "source_element_id", on_delete: :nullify
  add_foreign_key "network_cables", "map_elements", column: "target_element_id", on_delete: :nullify
  add_foreign_key "network_cables", "map_nodes", column: "source_node_id"
  add_foreign_key "network_cables", "map_nodes", column: "target_node_id"
  add_foreign_key "network_cables", "map_pops", column: "source_pop_id"
  add_foreign_key "network_cables", "map_pops", column: "target_pop_id"
  add_foreign_key "network_cables", "network_links"
  add_foreign_key "network_cables", "network_maps"
  add_foreign_key "network_links", "devices", column: "source_device_id"
  add_foreign_key "network_links", "devices", column: "target_device_id"
  add_foreign_key "network_links", "organizations"
  add_foreign_key "network_links", "sites", column: "source_site_id"
  add_foreign_key "network_links", "sites", column: "target_site_id"
  add_foreign_key "network_map_snapshots", "network_maps"
  add_foreign_key "network_maps", "organizations"
  add_foreign_key "network_maps", "zabbix_connections"
  add_foreign_key "sites", "organizations"
  add_foreign_key "zabbix_connections", "organizations"
  add_foreign_key "zabbix_hosts", "zabbix_connections"
  add_foreign_key "zabbix_items", "zabbix_connections"
  add_foreign_key "zabbix_items", "zabbix_hosts"
  add_foreign_key "zabbix_links", "organizations"
  add_foreign_key "zabbix_links", "zabbix_connections"
end
