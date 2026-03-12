class CreateMapNodeItems < ActiveRecord::Migration[8.0]
  def change
    create_table :map_node_items do |t|
      t.references :map_node, null: false, foreign_key: true
      t.references :zabbix_item, null: false, foreign_key: { to_table: :zabbix_items }
      t.string :alias
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :map_node_items, %i[map_node_id zabbix_item_id],
              unique: true,
              name: "index_map_node_items_on_node_and_item"
  end
end
