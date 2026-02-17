class CreateNetworkCables < ActiveRecord::Migration[8.0]
  def change
    create_table :network_cables do |t|
      t.references :network_map, null: false, foreign_key: true
      t.references :source_node, null: false, foreign_key: { to_table: :map_nodes }
      t.references :target_node, null: false, foreign_key: { to_table: :map_nodes }
      t.string :label
      t.string :cable_type, null: false, default: "logical"
      t.string :status, null: false, default: "unknown"
      t.integer :bandwidth_mbps
      t.decimal :length_meters, precision: 10, scale: 2
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :network_cables,
              [ :network_map_id, :source_node_id, :target_node_id ],
              unique: true,
              name: "index_network_cables_on_map_source_target"

    add_check_constraint :network_cables,
                         "source_node_id <> target_node_id",
                         name: "network_cables_source_target_diff"
  end
end
