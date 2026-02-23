class CreateMapPopsAndCablePopLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :map_pops do |t|
      t.references :network_map, null: false, foreign_key: true
      t.string :name, null: false
      t.string :external_id, null: false
      t.decimal :lat, precision: 10, scale: 6, null: false
      t.decimal :lng, precision: 10, scale: 6, null: false
      t.string :color, null: false, default: "#7c3aed"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :map_pops, [ :network_map_id, :external_id ], unique: true
    add_index :map_pops, [ :network_map_id, :name ]

    add_reference :map_nodes, :map_pop, foreign_key: true

    add_reference :network_cables, :source_pop, foreign_key: { to_table: :map_pops }
    add_reference :network_cables, :target_pop, foreign_key: { to_table: :map_pops }
  end
end
