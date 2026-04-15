class CreateDeviceMonitoringItems < ActiveRecord::Migration[8.0]
  def change
    create_table :device_monitoring_items do |t|
      t.references :device_monitoring_profile, null: false, foreign_key: true
      t.references :zabbix_item, null: false, foreign_key: { to_table: :zabbix_items }
      t.string :alias
      t.string :category
      t.string :subcategory
      t.string :usage, null: false, default: "map"
      t.integer :display_priority, null: false, default: 0
      t.boolean :map_visibility, null: false, default: false
      t.boolean :is_primary_metric, null: false, default: false
      t.boolean :is_health_metric, null: false, default: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :device_monitoring_items, %i[device_monitoring_profile_id zabbix_item_id], unique: true, name: "index_device_monitoring_items_on_profile_and_item"
  end
end
