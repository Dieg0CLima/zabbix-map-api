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

  test "returns payload unchanged when hostid is not synced locally" do
    organization = Organization.create!(name: "Org Linker Not Found")
    connection = organization.zabbix_connections.create!(
      name: "Conn Not Found",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )
    network_map = organization.network_maps.create!(name: "Mapa Not Found", source_type: "manual", zabbix_connection: connection)

    payload = { zabbix_host_id: "99999", label: "Node" }
    linked = MapNodes::ZabbixHostLinker.new(network_map: network_map, payload: payload).call

    # Placeholder creation was removed to prevent ghost records.
    # Payload is returned unchanged; model validation will reject if host not found.
    assert_equal "99999", linked[:zabbix_host_id].to_s
    assert connection.zabbix_hosts.find_by(hostid: "99999").blank?,
           "No placeholder host should be created silently"
  end
end
