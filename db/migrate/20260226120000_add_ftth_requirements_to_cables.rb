class AddFtthRequirementsToCables < ActiveRecord::Migration[8.0]
  def change
    change_column :network_cable_points, :x, :decimal, precision: 12, scale: 6, null: false
    change_column :network_cable_points, :y, :decimal, precision: 12, scale: 6, null: false

    create_table :network_cable_events do |t|
      t.references :network_map, null: false, foreign_key: true
      t.references :network_cable, null: true, foreign_key: true
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.string :actor
      t.jsonb :before_state, null: false, default: {}
      t.jsonb :after_state, null: false, default: {}
      t.text :notes

      t.timestamps
    end

    add_index :network_cable_events, [ :network_cable_id, :occurred_at ]
    add_index :network_cable_events, [ :network_map_id, :occurred_at ]
  end
end
