class CreateMapNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :map_nodes do |t|
      t.references :network_map, null: false, foreign_key: true
      t.string :label, null: false
      t.string :node_kind, null: false
      t.decimal :x, precision: 10, scale: 2, null: false
      t.decimal :y, precision: 10, scale: 2, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :zabbix_ref

      t.timestamps
    end

    add_index :map_nodes, [ :network_map_id, :node_kind ]
    add_index :map_nodes, [ :network_map_id, :zabbix_ref ]
  end
end
