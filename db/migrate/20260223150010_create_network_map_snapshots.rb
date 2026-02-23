class CreateNetworkMapSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :network_map_snapshots do |t|
      t.references :network_map, null: false, foreign_key: true
      t.string :label, null: false
      t.jsonb :state, null: false, default: {}

      t.timestamps
    end

    add_index :network_map_snapshots, [ :network_map_id, :created_at ]
  end
end
