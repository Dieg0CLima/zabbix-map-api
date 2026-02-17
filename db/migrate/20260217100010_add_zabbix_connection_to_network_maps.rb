class AddZabbixConnectionToNetworkMaps < ActiveRecord::Migration[8.0]
  def change
    add_reference :network_maps, :zabbix_connection, foreign_key: true
  end
end
