require "test_helper"
require_relative "../../../support/device_replacement_support"

# REQ-009: religar o equipamento a outro host do Zabbix (hostid diferente, mesmo IP).
# CA10 conflito de vínculo, CA11 religar, CA16/CA17 itens e bindings do host antigo.
# Zabbix::HostDetailsFetcher é sempre stubado (sem rede).
#
# Contrato assumido para CA16 (a resposta informa quantos foram removidos):
#   resposta do PATCH /devices/:id e do PATCH .../monitoring/host-link traz
#   meta.removed_monitoring = { "items" => n, "bindings" => n } (zeros quando nada foi apagado).
class Api::V1::DevicesRelinkTest < ActionDispatch::IntegrationTest
  include DeviceReplacementSupport

  OLD_HOST = "10572".freeze
  NEW_HOST = "20001".freeze

  setup do
    setup_replacement_world
    @device = build_device
    @old_link = link_host(@device, @connection, OLD_HOST, name: "SW-ANTIGO")
    @profile = Devices::MonitoringProfileSync.new(device: @device).call
    @zitem_a = build_item(@connection, "7001")
    @zitem_b = build_item(@connection, "7002")
    @monitoring_item_a = @profile.device_monitoring_items.create!(zabbix_item: @zitem_a, usage: "map", alias: "In")
    @monitoring_item_b = @profile.device_monitoring_items.create!(zabbix_item: @zitem_b, usage: "map", alias: "Out")
    @map = build_map("Mapa troca")
    @node = build_node(@map, "SW", mappable: @device)
    @binding = @node.monitoring_bindings.create!(zabbix_link: @old_link, metric_type: "status")
    @payloads = {
      OLD_HOST => host_payload(OLD_HOST, name: "SW-ANTIGO"),
      NEW_HOST => host_payload(NEW_HOST, name: "SW-NOVO", vendor: "Huawei", model: "S6730")
    }
  end

  def patch_device(device = @device, device_params: {}, role: :editor)
    patch "/api/v1/devices/#{device.id}", params: { organization_id: @org.id, device: device_params }, headers: auth_for(role), as: :json
  end

  def relink_params(hostid = NEW_HOST, extra = {})
    { zabbix_connection_id: @connection.id, zabbix_host_id: hostid }.merge(extra)
  end

  def host_links(device = @device)
    ZabbixLink.where(linkable: device, resource_type: "host")
  end

  def assert_monitoring_untouched
    assert DeviceMonitoringItem.exists?(@monitoring_item_a.id)
    assert DeviceMonitoringItem.exists?(@monitoring_item_b.id)
    assert MapMonitoringBinding.exists?(@binding.id)
  end

  # ---- CA10 ----

  test "CA10: linking a host already used by another device is 422 VALIDATION_ERROR in pt-BR citing that device (PATCH)" do
    owner = build_device(name: "Switch Dono do Host", hostname: "dono", management_ip: "10.6.6.6")
    link_host(owner, @connection, NEW_HOST, name: "SW-NOVO")

    with_host_details(@payloads) { patch_device(device_params: relink_params) }

    assert_response :unprocessable_entity
    assert_equal "VALIDATION_ERROR", json["code"]
    detail = json.dig("errors", 0, "detail")
    assert_includes detail, "Switch Dono do Host"
    assert_match(/v[íi]nculado|j[áa]/i, detail)
    assert_no_match(/taken|already|unique|duplicate|PG::/i, detail)
    assert_equal OLD_HOST, host_links.first.external_id
    assert_equal 1, host_links(owner).count
  end

  test "CA10: same conflict through PATCH monitoring/host-link" do
    owner = build_device(name: "Switch Dono do Host", hostname: "dono", management_ip: "10.6.6.6")
    link_host(owner, @connection, NEW_HOST, name: "SW-NOVO")

    with_host_details(@payloads) do
      patch "/api/v1/devices/#{@device.id}/monitoring/host-link",
            params: { organization_id: @org.id, monitoring_host_link: relink_params }, headers: auth_for(:editor), as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "VALIDATION_ERROR", json["code"]
    assert_includes json.dig("errors", 0, "detail"), "Switch Dono do Host"
    assert_equal OLD_HOST, host_links.first.external_id
  end

  test "CA10: linking a free host to a device that has none still works (no false positive)" do
    bare = build_device(name: "Sem host", hostname: "sem-host", management_ip: "10.1.2.3")

    with_host_details(@payloads) { patch_device(bare, device_params: relink_params) }

    assert_response :ok
    assert_equal NEW_HOST, host_links(bare).first.external_id
  end

  test "CA10: re-sending the host the device already has is not a conflict" do
    with_host_details(@payloads) { patch_device(device_params: relink_params(OLD_HOST)) }

    assert_response :ok
    assert_equal [ OLD_HOST ], host_links.pluck(:external_id)
  end

  # ---- CA11 ----

  test "CA11: PATCH with the new hostid and confirmed fields rewires the single host link and writes the fields" do
    old_synced_at = @old_link.metadata["synced_at"]

    with_host_details(@payloads) do
      patch_device(device_params: relink_params(NEW_HOST, hostname: "sw-novo", vendor: "Huawei", model: "S6730", management_ip: "10.0.0.1"))
    end

    assert_response :ok
    assert_equal 1, host_links.count, "um único vínculo host por equipamento"
    link = host_links.first
    assert_equal NEW_HOST, link.external_id
    assert_equal "SW-NOVO", link.name
    assert_equal NEW_HOST, link.metadata["hostid"]
    assert_equal "10.0.0.1", link.metadata.dig("interfaces", 0, "ip")
    assert_operator Time.zone.parse(link.metadata["synced_at"]), :>, Time.zone.parse(old_synced_at)

    @device.reload
    assert_equal "sw-novo", @device.hostname
    assert_equal "S6730", @device.model
    assert_equal "10.0.0.1", @device.management_ip
    assert_equal NEW_HOST, json.dig("data", "zabbix_host_id")
  end

  test "CA11: fields that are not sent stay as they were and serial_number is never changed by the flow" do
    with_host_details(@payloads) { patch_device(device_params: relink_params(NEW_HOST, hostname: "sw-novo")) }

    assert_response :ok
    @device.reload
    assert_equal "sw-novo", @device.hostname
    assert_equal "Huawei", @device.vendor
    assert_equal "S5720", @device.model
    assert_equal "10.0.0.1", @device.management_ip
    assert_equal "SN-ANTIGO", @device.serial_number
  end

  test "CA11: the host-link endpoint rewires the host too" do
    with_host_details(@payloads) do
      patch "/api/v1/devices/#{@device.id}/monitoring/host-link",
            params: { organization_id: @org.id, monitoring_host_link: relink_params }, headers: auth_for(:editor), as: :json
    end

    assert_response :ok
    assert_equal [ NEW_HOST ], host_links.pluck(:external_id)
  end

  # ---- CA16 ----

  test "CA16: relinking to a different hostid deletes the old host's monitoring items and bindings, new link starts empty" do
    with_host_details(@payloads) { patch_device(device_params: relink_params) }

    assert_response :ok
    assert_equal 0, DeviceMonitoringItem.where(id: [ @monitoring_item_a.id, @monitoring_item_b.id ]).count
    assert_equal 0, DeviceMonitoringItem.joins(:profile).where(device_monitoring_profiles: { device_id: @device.id }).count
    assert_equal 0, MapMonitoringBinding.where(id: @binding.id).count
    assert MapNode.exists?(@node.id), "o nó do mapa permanece"
    assert_equal NEW_HOST, host_links.first.external_id
  end

  test "CA16: the response reports how many items and bindings were removed" do
    with_host_details(@payloads) { patch_device(device_params: relink_params) }

    assert_response :ok
    assert_equal({ "items" => 2, "bindings" => 1 }, json.dig("meta", "removed_monitoring"))
  end

  test "CA16: same through host-link, and the response reports the counts" do
    with_host_details(@payloads) do
      patch "/api/v1/devices/#{@device.id}/monitoring/host-link",
            params: { organization_id: @org.id, monitoring_host_link: relink_params }, headers: auth_for(:editor), as: :json
    end

    assert_response :ok
    assert_equal 0, DeviceMonitoringItem.where(id: [ @monitoring_item_a.id, @monitoring_item_b.id ]).count
    assert_equal 0, MapMonitoringBinding.where(id: @binding.id).count
    assert_equal({ "items" => 2, "bindings" => 1 }, json.dig("meta", "removed_monitoring"))
  end

  test "CA16: bindings of another device on the same map are untouched" do
    other = build_device(name: "Outro", hostname: "outro", management_ip: "10.5.5.5")
    other_link = link_host(other, @connection, "30001")
    other_node = build_node(@map, "Outro", mappable: other)
    other_binding = other_node.monitoring_bindings.create!(zabbix_link: other_link, metric_type: "status")

    with_host_details(@payloads) { patch_device(device_params: relink_params) }

    assert_response :ok
    assert MapMonitoringBinding.exists?(other_binding.id)
  end

  test "CA16: with the same hostid nothing is deleted and removed counts are zero" do
    with_host_details(@payloads) { patch_device(device_params: relink_params(OLD_HOST, hostname: "sw-novo-nome")) }

    assert_response :ok
    assert_monitoring_untouched
    assert_equal({ "items" => 0, "bindings" => 0 }, json.dig("meta", "removed_monitoring"))
  end

  test "CA16: updating other fields without touching the zabbix link keeps monitoring" do
    patch_device(device_params: { model: "S6730" })

    assert_response :ok
    assert_monitoring_untouched
  end

  # ---- CA17 ----

  test "CA17: host that does not exist in Zabbix fails the relink and keeps items and bindings" do
    with_host_details(@payloads) { patch_device(device_params: relink_params("99999")) }

    assert_response :unprocessable_entity
    assert_monitoring_untouched
    assert_equal OLD_HOST, host_links.first.external_id
  end

  test "CA17: Zabbix failing during the relink keeps items, bindings and the old link" do
    failing = @payloads.merge(NEW_HOST => Zabbix::HostDetailsFetcher::Error.new("connection refused"))

    with_host_details(failing) { patch_device(device_params: relink_params) }

    assert_response :unprocessable_entity
    assert_monitoring_untouched
    assert_equal OLD_HOST, host_links.first.external_id
  end

  test "CA17: conflict (CA10) keeps items and bindings, also through host-link" do
    owner = build_device(name: "Switch Dono do Host", hostname: "dono", management_ip: "10.6.6.6")
    link_host(owner, @connection, NEW_HOST)

    with_host_details(@payloads) { patch_device(device_params: relink_params) }
    assert_response :unprocessable_entity
    assert_monitoring_untouched

    with_host_details(@payloads) do
      patch "/api/v1/devices/#{@device.id}/monitoring/host-link",
            params: { organization_id: @org.id, monitoring_host_link: relink_params }, headers: auth_for(:editor), as: :json
    end
    assert_response :unprocessable_entity
    assert_monitoring_untouched
  end

  test "CA17: an invalid field in the same PATCH rolls the relink back entirely" do
    with_host_details(@payloads) { patch_device(device_params: relink_params(NEW_HOST, status: "status-inexistente")) }

    assert_response :unprocessable_entity
    assert_monitoring_untouched
    assert_equal OLD_HOST, host_links.first.external_id
  end

  # ---- RBAC do fluxo de religar ----

  test "RBAC: viewer cannot relink (403) and anonymous gets 401, nothing changes" do
    with_host_details(@payloads) { patch_device(device_params: relink_params, role: :viewer) }
    assert_response :forbidden
    assert_monitoring_untouched
    assert_equal OLD_HOST, host_links.first.external_id

    patch "/api/v1/devices/#{@device.id}", params: { organization_id: @org.id, device: relink_params }, as: :json
    assert_response :unauthorized
    assert_equal OLD_HOST, host_links.first.external_id
  end

  test "RBAC: a device from another organization cannot be relinked (404)" do
    with_host_details(@payloads) do
      patch "/api/v1/devices/#{@device.id}", params: { organization_id: @other_org.id, device: relink_params }, headers: auth_for(:foreign), as: :json
    end

    assert_response :not_found
    assert_equal OLD_HOST, host_links.first.external_id
    assert_monitoring_untouched
  end
end
