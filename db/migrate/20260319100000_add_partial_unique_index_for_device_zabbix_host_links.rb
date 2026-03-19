class AddPartialUniqueIndexForDeviceZabbixHostLinks < ActiveRecord::Migration[8.0]
  INDEX_NAME = "idx_unique_device_host_zabbix_links"

  def change
    return unless table_exists?(:zabbix_links)

    add_index :zabbix_links,
              [:linkable_type, :linkable_id, :resource_type],
              unique: true,
              where: "linkable_type = 'Device' AND resource_type = 'host'",
              name: INDEX_NAME,
              if_not_exists: true
  end
end
