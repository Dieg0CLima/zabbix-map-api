class CreateCableFusionStructures < ActiveRecord::Migration[8.0]
  def change
    create_table :cable_fusion_diagrams do |t|
      t.references :network_cable, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "draft"
      t.integer :version, null: false, default: 0
      t.datetime :published_at
      t.references :published_by_user, foreign_key: { to_table: :users }
      t.datetime :last_validated_at
      t.integer :validation_errors_count, null: false, default: 0
      t.string :structure_checksum
      t.integer :lock_version, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    create_table :cable_fusion_nodes do |t|
      t.references :diagram, null: false, foreign_key: { to_table: :cable_fusion_diagrams }
      t.string :client_ref
      t.string :node_type, null: false
      t.string :label
      t.float :x, null: false, default: 0.0
      t.float :y, null: false, default: 0.0
      t.float :rotation, null: false, default: 0.0
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :cable_fusion_nodes, [ :diagram_id, :client_ref ], unique: true, where: "client_ref IS NOT NULL"

    create_table :cable_fusion_ports do |t|
      t.references :node, null: false, foreign_key: { to_table: :cable_fusion_nodes }
      t.string :client_ref
      t.string :name, null: false
      t.string :port_type, null: false
      t.integer :capacity, null: false, default: 1
      t.integer :occupancy_limit, null: false, default: 1
      t.float :position_x
      t.float :position_y
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :cable_fusion_ports, [ :node_id, :client_ref ], unique: true, where: "client_ref IS NOT NULL"

    create_table :cable_fusion_links do |t|
      t.references :diagram, null: false, foreign_key: { to_table: :cable_fusion_diagrams }
      t.string :client_ref
      t.references :source_port, null: false, foreign_key: { to_table: :cable_fusion_ports }
      t.references :target_port, null: false, foreign_key: { to_table: :cable_fusion_ports }
      t.string :link_kind, null: false, default: "splice"
      t.string :fiber_side
      t.integer :fiber_number
      t.string :status, null: false, default: "draft"
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :cable_fusion_links, [ :diagram_id, :client_ref ], unique: true, where: "client_ref IS NOT NULL"
    add_index :cable_fusion_links, [ :diagram_id, :fiber_side, :fiber_number ], where: "fiber_side IS NOT NULL AND fiber_number IS NOT NULL", name: "idx_cable_fusion_links_fiber_ref"

    create_table :cable_fusion_snapshots do |t|
      t.references :diagram, null: false, foreign_key: { to_table: :cable_fusion_diagrams }
      t.integer :version, null: false
      t.jsonb :payload, null: false, default: {}
      t.references :created_by_user, foreign_key: { to_table: :users }
      t.string :reason
      t.boolean :published, null: false, default: false
      t.timestamps
    end
    add_index :cable_fusion_snapshots, [ :diagram_id, :version ], unique: true
  end
end
