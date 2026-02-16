class CreateNetworkCablePoints < ActiveRecord::Migration[8.0]
  def change
    create_table :network_cable_points do |t|
      t.references :network_cable, null: false, foreign_key: true
      t.integer :position, null: false
      t.decimal :x, precision: 10, scale: 2, null: false
      t.decimal :y, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :network_cable_points, [ :network_cable_id, :position ], unique: true
  end
end
