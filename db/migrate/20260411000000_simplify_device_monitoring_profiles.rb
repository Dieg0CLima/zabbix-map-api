class SimplifyDeviceMonitoringProfiles < ActiveRecord::Migration[8.0]
  def up
    # Remove FK before dropping the column
    remove_foreign_key :device_monitoring_profiles, :zabbix_connections, if_exists: true

    remove_column :device_monitoring_profiles, :zabbix_connection_id, :bigint
    remove_column :device_monitoring_profiles, :zabbix_hostid,        :string
    remove_column :device_monitoring_profiles, :host_label,           :string
    remove_column :device_monitoring_profiles, :host_metadata,        :jsonb
    # synced_at is kept: used to track when items were last refreshed
  end

  def down
    add_column :device_monitoring_profiles, :host_metadata,        :jsonb,   default: {}, null: false
    add_column :device_monitoring_profiles, :host_label,           :string
    add_column :device_monitoring_profiles, :zabbix_hostid,        :string
    add_reference :device_monitoring_profiles, :zabbix_connection, foreign_key: true
  end
end
