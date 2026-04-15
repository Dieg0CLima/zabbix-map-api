class CreateDeviceMonitoringProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :device_monitoring_profiles do |t|
      t.references :device, null: false, foreign_key: true
      t.references :zabbix_connection, foreign_key: true
      t.string :zabbix_hostid
      t.string :host_label
      t.jsonb :host_metadata, default: {}, null: false
      t.datetime :synced_at
      t.timestamps
    end

    add_index :device_monitoring_profiles, :device_id, unique: true unless index_exists?(:device_monitoring_profiles, :device_id)
  end
end
