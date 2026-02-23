class AddVisualEditorFieldsToNetworkTopology < ActiveRecord::Migration[8.0]
  def up
    add_column :network_maps, :active_base_layer, :string, null: false, default: "standard"

    add_column :map_nodes, :external_id, :string
    add_column :map_nodes, :icon, :string
    add_column :map_nodes, :color, :string
    add_column :map_nodes, :size, :integer
    add_column :map_nodes, :lat, :decimal, precision: 10, scale: 6
    add_column :map_nodes, :lng, :decimal, precision: 10, scale: 6

    add_index :map_nodes, [ :network_map_id, :external_id ], unique: true

    add_column :network_cables, :external_id, :string
    add_column :network_cables, :color, :string
    add_column :network_cables, :weight, :integer
    add_column :network_cables, :pattern, :string, null: false, default: "solid"

    add_index :network_cables, [ :network_map_id, :external_id ], unique: true

    remove_check_constraint :network_cables, name: "network_cables_source_target_diff"
    remove_index :network_cables, name: "index_network_cables_on_map_source_target"

    change_column_null :network_cables, :source_node_id, true
    change_column_null :network_cables, :target_node_id, true

    add_index :network_cables,
              [ :network_map_id, :source_node_id, :target_node_id ],
              unique: true,
              where: "source_node_id IS NOT NULL AND target_node_id IS NOT NULL",
              name: "index_network_cables_on_map_source_target"

    execute <<~SQL.squish
      UPDATE map_nodes
      SET lat = x,
          lng = y,
          icon = 'pi-server',
          color = '#2563eb',
          size = 30,
          external_id = 'legacy-node-' || id
      WHERE lat IS NULL OR lng IS NULL OR icon IS NULL OR color IS NULL OR size IS NULL OR external_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE network_cables
      SET color = '#0891b2',
          weight = 4,
          pattern = 'solid',
          external_id = 'legacy-cable-' || id
      WHERE color IS NULL OR weight IS NULL OR pattern IS NULL OR external_id IS NULL
    SQL

    change_column_null :map_nodes, :external_id, false
    change_column_null :map_nodes, :icon, false
    change_column_null :map_nodes, :color, false
    change_column_null :map_nodes, :size, false
    change_column_null :map_nodes, :lat, false
    change_column_null :map_nodes, :lng, false

    change_column_null :network_cables, :external_id, false
    change_column_null :network_cables, :color, false
    change_column_null :network_cables, :weight, false
  end

  def down
    remove_index :network_cables, name: "index_network_cables_on_map_source_target"

    change_column_null :network_cables, :source_node_id, false
    change_column_null :network_cables, :target_node_id, false

    add_index :network_cables,
              [ :network_map_id, :source_node_id, :target_node_id ],
              unique: true,
              name: "index_network_cables_on_map_source_target"

    add_check_constraint :network_cables,
                         "source_node_id <> target_node_id",
                         name: "network_cables_source_target_diff"

    remove_index :network_cables, [ :network_map_id, :external_id ]
    remove_column :network_cables, :pattern
    remove_column :network_cables, :weight
    remove_column :network_cables, :color
    remove_column :network_cables, :external_id

    remove_index :map_nodes, [ :network_map_id, :external_id ]
    remove_column :map_nodes, :lng
    remove_column :map_nodes, :lat
    remove_column :map_nodes, :size
    remove_column :map_nodes, :color
    remove_column :map_nodes, :icon
    remove_column :map_nodes, :external_id

    remove_column :network_maps, :active_base_layer
  end
end
