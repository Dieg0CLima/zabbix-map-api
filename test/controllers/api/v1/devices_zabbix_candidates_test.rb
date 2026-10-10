require "test_helper"
require_relative "../../../support/device_replacement_support"

# REQ-009: GET /devices/:id/zabbix_candidates (somente leitura, busca de hosts do Zabbix por IP).
# Contrato assumido para o isolamento (sem rede): Zabbix::HostCandidatesFetcher.new(connection:, ip:, limit:).call
# devolve um array de hashes no formato de Zabbix::HostPayloadBuilder#details_payload, já filtrados pelo IP exato.
class Api::V1::DevicesZabbixCandidatesTest < ActionDispatch::IntegrationTest
  include DeviceReplacementSupport

  setup do
    setup_replacement_world
    @device = build_device
    @new_host = candidate_payload("20001", "SW-GUARDA-NOVO", "10.0.0.1")
  end

  def candidate_payload(hostid, name, ip, vendor: "Huawei", model: "S6730")
    {
      hostid: hostid, name: name, host: name.downcase, status: "enabled", available: true,
      interfaces: [ { ip: ip, dns: "", type: "snmp", main: true } ],
      inventory: { vendor: vendor, model: model },
      metadata: { host: name.downcase },
      suggested_device_attributes: { name: name, hostname: name.downcase, management_ip: ip, vendor: vendor, model: model }
    }
  end

  # Registra os argumentos recebidos pelo fetcher e devolve `result` (array ou exceção).
  def with_candidates(result)
    @calls = []
    calls = @calls
    factory = lambda do |**kwargs|
      calls << kwargs
      FakeCandidates.new(result)
    end
    Zabbix::HostCandidatesFetcher.stub(:new, factory) { yield }
  end

  def candidates(device: @device, params: {}, role: :editor, org: @org)
    get "/api/v1/devices/#{device.id}/zabbix_candidates", params: { organization_id: org.id }.merge(params), headers: auth_for(role)
  end

  # ---- CA7 ----

  test "CA7: returns candidates with the full documented shape and linked_device null when free" do
    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :ok
    row = json.dig("data", 0)
    %w[hostid name host status available interfaces inventory suggested_device_attributes linked_device].each do |key|
      assert row.key?(key), "candidato deve trazer #{key}"
    end
    assert_equal "20001", row["hostid"]
    assert_equal "SW-GUARDA-NOVO", row["name"]
    assert_equal "10.0.0.1", row.dig("interfaces", 0, "ip")
    assert_equal "Huawei", row.dig("inventory", "vendor")
    assert_equal "10.0.0.1", row.dig("suggested_device_attributes", "management_ip")
    assert_nil row["linked_device"]
  end

  test "CA7: asks the fetcher for the exact ip, the connection of the organization and a limit of at most 20" do
    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :ok
    assert_equal 1, @calls.size
    assert_equal @connection.id, @calls.first[:connection].id
    assert_equal "10.0.0.1", @calls.first[:ip]
    assert_operator @calls.first[:limit].to_i, :<=, 20
  end

  test "CA7: candidates already linked to another device come with linked_device {id,name}" do
    other = build_device(name: "Switch com host", hostname: "sw-outro", management_ip: "10.7.7.7")
    link_host(other, @connection, "20001")

    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :ok
    assert_equal({ "id" => other.id, "name" => "Switch com host" }, json.dig("data", 0, "linked_device"))
  end

  test "CA7: a host linked to this very device is not blocked for it (linked_device points to itself or is null)" do
    link_host(@device, @connection, "20001")

    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :ok
    linked = json.dig("data", 0, "linked_device")
    assert linked.nil? || linked["id"] == @device.id
  end

  test "CA7: the connection of the current host link is used when zabbix_connection_id is omitted" do
    link_host(@device, @connection, "10572")

    with_candidates([ @new_host ]) do
      candidates(params: { ip: "10.0.0.1" })
    end

    assert_response :ok
    assert_equal @connection.id, @calls.first[:connection].id
  end

  test "CA7: does not write anything (device and links untouched)" do
    link = link_host(@device, @connection, "10572")
    before = [ @device.reload.attributes, link.reload.attributes ]

    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :ok
    assert_equal before, [ @device.reload.attributes, link.reload.attributes ]
    assert_equal 1, ZabbixLink.where(linkable: @device).count
  end

  test "CA7: connection from another organization is 404" do
    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @other_connection.id, ip: "10.0.0.1" })
    end

    assert_response :not_found
    assert_empty @calls
  end

  # ---- CA8 ----

  test "CA8: ip omitted falls back to the device management_ip" do
    with_candidates([ @new_host ]) do
      candidates(params: { zabbix_connection_id: @connection.id })
    end

    assert_response :ok
    assert_equal "10.0.0.1", @calls.first[:ip]
  end

  test "CA8: explicit ip wins over the device management_ip" do
    with_candidates([]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.5.5.5" })
    end

    assert_response :ok
    assert_equal "10.5.5.5", @calls.first[:ip]
  end

  test "CA8: IPv6 is accepted" do
    with_candidates([]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "2001:db8::1" })
    end

    assert_response :ok
    assert_equal "2001:db8::1", @calls.first[:ip]
  end

  test "CA8: no ip and no management_ip is 422 VALIDATION_ERROR and never reaches Zabbix" do
    bare = build_device(name: "Sem IP", hostname: "sem-ip", management_ip: nil)

    with_candidates([]) do
      candidates(device: bare, params: { zabbix_connection_id: @connection.id })
    end

    assert_response :unprocessable_entity
    assert_equal "VALIDATION_ERROR", json["code"]
    assert_empty @calls
  end

  test "CA8: malformed ip is 422 VALIDATION_ERROR and never reaches Zabbix" do
    [ "10.0.0", "10.0.0.256", "abc", "10.0.0.1; DROP TABLE hosts", "10.0.0.%" ].each do |ip|
      with_candidates([]) do
        candidates(params: { zabbix_connection_id: @connection.id, ip: ip })
      end

      assert_response :unprocessable_entity, "ip=#{ip.inspect}"
      assert_equal "VALIDATION_ERROR", json["code"], "ip=#{ip.inspect}"
      assert_empty @calls, "ip=#{ip.inspect}"
    end
  end

  test "CA8: no candidates is 200 with an empty list" do
    with_candidates([]) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.99.99.99" })
    end

    assert_response :ok
    assert_equal [], json["data"]
  end

  test "CA8: zabbix_connection_id is required when the device has no host link and none is given" do
    with_candidates([]) do
      candidates(params: { ip: "10.0.0.1" })
    end

    assert_response :unprocessable_entity
    assert_equal "VALIDATION_ERROR", json["code"]
    assert_empty @calls
  end

  # ---- CA9 ----

  test "CA9: Zabbix unavailable is 503 SERVICE_UNAVAILABLE and the device is not changed" do
    link = link_host(@device, @connection, "10572")
    before = [ @device.reload.attributes, link.reload.attributes ]

    with_candidates(Zabbix::HostCandidatesFetcher::Error.new("connection refused")) do
      candidates(params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :service_unavailable
    assert_equal "SERVICE_UNAVAILABLE", json["code"]
    assert_equal before, [ @device.reload.attributes, link.reload.attributes ]
  end

  # ---- CA6-style RBAC for the new endpoint (REQ: Autorização) ----

  test "RBAC: anonymous gets 401" do
    with_candidates([ @new_host ]) do
      get "/api/v1/devices/#{@device.id}/zabbix_candidates", params: { organization_id: @org.id, zabbix_connection_id: @connection.id, ip: "10.0.0.1" }
    end

    assert_response :unauthorized
    assert_empty @calls
  end

  test "RBAC: viewer gets 403 and Zabbix is not queried" do
    with_candidates([ @new_host ]) do
      candidates(role: :viewer, params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :forbidden
    assert_equal "FORBIDDEN", json["code"]
    assert_empty @calls
  end

  test "RBAC: a device from another organization is 404 and Zabbix is not queried" do
    foreign = build_device(name: "Alheio", org: @other_org, hostname: "alheio", management_ip: "10.8.8.8")

    with_candidates([ @new_host ]) do
      candidates(device: foreign, params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :not_found
    assert_empty @calls
  end

  test "RBAC: organization admin can search" do
    with_candidates([ @new_host ]) do
      candidates(role: :admin, params: { zabbix_connection_id: @connection.id, ip: "10.0.0.1" })
    end

    assert_response :ok
  end
end
