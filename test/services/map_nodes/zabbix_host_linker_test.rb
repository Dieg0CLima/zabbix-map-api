require "test_helper"

class MapNodes::ZabbixHostLinkerTest < ActiveSupport::TestCase
  test "maps payload zabbix_host_id from hostid to local host id" do
    organization = Organization.create!(name: "Org Linker")
    connection = organization.zabbix_connections.create!(
      name: "Conn",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )
    network_map = organization.network_maps.create!(name: "Mapa", source_type: "manual", zabbix_connection: connection)
    host = connection.zabbix_hosts.create!(hostid: "10658", name: "SWCX")

    payload = { zabbix_host_id: "10658", label: "Node" }

    linked = MapNodes::ZabbixHostLinker.new(network_map: network_map, payload: payload).call

    assert_equal host.id, linked[:zabbix_host_id]
    assert_equal "10658", linked[:zabbix_ref]
  end

  test "nils out zabbix_host_id and preserves zabbix_ref when hostid is not synced locally" do
    organization = Organization.create!(name: "Org Linker Not Found")
    connection = organization.zabbix_connections.create!(
      name: "Conn Not Found",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )
    network_map = organization.network_maps.create!(name: "Mapa Not Found", source_type: "manual", zabbix_connection: connection)

    # Simulates db mode: host "99999" exists in Zabbix but is not in local zabbix_hosts table.
    payload = { zabbix_host_id: "99999", label: "Node" }
    linked = MapNodes::ZabbixHostLinker.new(network_map: network_map, payload: payload).call

    # FK is nulled to avoid PG::ForeignKeyViolation; soft reference is preserved.
    assert_nil linked[:zabbix_host_id], "zabbix_host_id must be nil to avoid FK violation"
    assert_equal "99999", linked[:zabbix_ref], "zabbix_ref must be preserved for display"
    assert connection.zabbix_hosts.find_by(hostid: "99999").blank?,
           "No placeholder host should be created silently"
  end
end
