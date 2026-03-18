class CreateMapElementItems < ActiveRecord::Migration[8.0]
  # Replaces map_node_items: links a MapElement to a ZabbixItem for monitoring.
  # Decoupled from the device concept — any element (currently Device-typed) can
  # have monitored items.
  def change
    create_table :map_element_items do |t|
      t.references :map_element, null: false, foreign_key: true
      t.references :zabbix_item, null: false, foreign_key: true
      t.string :alias
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :map_element_items,
              %i[map_element_id zabbix_item_id],
              unique: true,
              name: "index_map_element_items_on_element_and_item"
  end
end
