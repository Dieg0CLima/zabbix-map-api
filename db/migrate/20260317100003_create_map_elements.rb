class CreateMapElements < ActiveRecord::Migration[8.0]
  # MapElement is the canonical "presence of a domain entity in a map".
  # It stores only visual/layout context specific to one map.
  # The entity itself (Site or Device) lives in its own table.
  def change
    create_table :map_elements, if_not_exists: true do |t|
      t.references :network_map, null: false, foreign_key: true

      # Polymorphic reference to the domain entity (Site, Device, or future types)
      t.references :mappable, polymorphic: true, null: false

      # Map-scoped stable identifier, used as the canonical element id in payloads
      t.string :external_id, null: false

      # Visual position on the map
      t.decimal :lat, precision: 10, scale: 6, null: false
      t.decimal :lng, precision: 10, scale: 6, null: false

      # Visual overrides — null means "use the entity's default"
      t.string :icon_override
      t.string :color_override
      t.string :label_override
      t.integer :size_override

      # Layout state
      t.boolean :collapsed, default: false, null: false
      t.integer :display_order, default: 0, null: false

      # Freeform visual metadata (e.g. badge, highlight, custom tooltip)
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :map_elements,
              %i[network_map_id external_id],
              unique: true,
              name: "index_map_elements_on_network_map_id_and_external_id",
              if_not_exists: true

    # Each domain entity can appear at most once per map
    add_index :map_elements,
              %i[network_map_id mappable_type mappable_id],
              unique: true,
              name: "index_map_elements_on_map_and_mappable",
              if_not_exists: true

    add_index :map_elements, %i[mappable_type mappable_id], if_not_exists: true
  end
end
