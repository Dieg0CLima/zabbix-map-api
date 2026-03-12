class AddZabbixHostIdToMapNodes < ActiveRecord::Migration[8.0]
  def change
    add_column :map_nodes, :zabbix_host_id, :bigint
    add_index :map_nodes, :zabbix_host_id, name: "index_map_nodes_on_zabbix_host_id"
    add_foreign_key :map_nodes, :zabbix_hosts, on_delete: :nullify
  end
end
