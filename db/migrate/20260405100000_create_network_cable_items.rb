class CreateNetworkCableItems < ActiveRecord::Migration[8.0]
  def change
    create_table :network_cable_items do |t|
      t.references :network_cable, null: false, foreign_key: true
      t.references :zabbix_item, null: false, foreign_key: true
      t.string :alias
      t.string :metric_role, null: false, default: "bandwidth_in"
      t.integer :display_order, null: false, default: 0

      t.timestamps
    end

    add_index :network_cable_items, [:network_cable_id, :zabbix_item_id],
              unique: true,
              name: "index_network_cable_items_on_cable_and_item"
  end
end
