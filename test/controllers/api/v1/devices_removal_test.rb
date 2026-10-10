require "test_helper"
require_relative "../../../support/device_replacement_support"

# REQ-009: DELETE /devices/:id com cascata transacional + GET /devices/:id/removal_impact.
# Sem rede: qualquer abertura de conexão com o Zabbix falha o teste (without_zabbix).
class Api::V1::DevicesRemovalTest < ActionDispatch::IntegrationTest
  include DeviceReplacementSupport

  ENGLISH_RAILS_TEXT = /cannot delete|dependent|restrict|record not|foreign key/i

  setup do
    setup_replacement_world
    @device = build_device
    @host_link = link_host(@device, @connection, "10572")
    @interface, @interface_link = add_interface_with_link(@device, @connection)
    @profile = Devices::MonitoringProfileSync.new(device: @device).call
  end

  def remove(device, role: :editor, confirm: nil, org: @org)
    params = { organization_id: org.id }
    params[:confirm] = confirm unless confirm.nil?
    delete "/api/v1/devices/#{device.id}", params: params, headers: auth_for(role), as: :json
  end

  def impact(device, role: :editor, org: @org)
    get "/api/v1/devices/#{device.id}/removal_impact", params: { organization_id: org.id }, headers: auth_for(role)
  end

  # Mapas com o equipamento: cada um com nó do equipamento, item, binding, aresta e cabo.
  def build_map_dependencies(map_count: 2)
    item = build_item(@connection, "9001")
    @maps = []
    @device_nodes = []
    @other_nodes = []
    @cables = []
    @edges = []
    map_count.times do |i|
      map = build_map("Mapa #{i} #{SecureRandom.hex(2)}")
      node = build_node(map, "Nó SW #{i}", mappable: @device)
      other_device = build_device(name: "Outro #{i}", hostname: "outro-#{i}", management_ip: "10.9.#{i}.1")
      other = build_node(map, "Outro #{i}", mappable: other_device)
      node.map_node_items.create!(zabbix_item: item, alias: "In", display_order: 1)
      node.monitoring_bindings.create!(zabbix_link: @host_link, metric_type: "status")
      @edges << MapEdge.create!(network_map: map, source_node: node, target_node: other, edge_type: "physical")
      @cables << build_cable(map, node, other)
      @maps << map
      @device_nodes << node
      @other_nodes << other
    end
  end

  # ---- CA1 ----

  test "CA1: editor deletes a device linked to Zabbix (no maps) with confirm=true and nothing is written to Zabbix" do
    without_zabbix do
      remove(@device, confirm: true)
    end

    assert_response :ok
    assert_equal true, json.dig("data", "removed")
    assert_not Device.exists?(@device.id)
    assert_equal 0, ZabbixLink.where(linkable_type: "Device", linkable_id: @device.id).count
    assert_equal 0, ZabbixLink.where(id: @interface_link.id).count
    assert_equal 0, DeviceInterface.where(device_id: @device.id).count
    assert_equal 0, DeviceMonitoringProfile.where(device_id: @device.id).count
  end

  test "CA1: organization admin can delete too, and confirm accepts the string \"true\"" do
    without_zabbix { remove(@device, role: :admin, confirm: "true") }

    assert_response :ok
    assert_not Device.exists?(@device.id)
  end

  test "CA1: response carries the impact that was removed" do
    remove(@device, confirm: true)

    assert_response :ok
    data = json.fetch("data")
    assert_equal @device.id, data.dig("impact", "device_id")
    assert_equal 1, data.dig("impact", "zabbix_links", "device")
    assert_equal 1, data.dig("impact", "zabbix_links", "interfaces")
    assert_equal 1, data.dig("impact", "interfaces")
  end

  # ---- CA2 / RN2 ----

  test "CA2: without confirm a device with links gets 422 DEVICE_REMOVAL_NEEDS_CONFIRMATION in pt-BR and nothing is deleted" do
    remove(@device)

    assert_response :unprocessable_entity
    assert_equal "DEVICE_REMOVAL_NEEDS_CONFIRMATION", json.dig("errors", 0, "code")
    detail = json.dig("errors", 0, "detail")
    assert detail.present?
    assert_match(/equipamento|v[íi]nculo|confirm/i, detail)
    assert_no_match ENGLISH_RAILS_TEXT, detail
    assert_equal 1, impact_from(json).dig("zabbix_links", "device")
    assert_equal 1, impact_from(json).dig("zabbix_links", "interfaces")
    assert Device.exists?(@device.id)
    assert ZabbixLink.exists?(@host_link.id)
    assert ZabbixLink.exists?(@interface_link.id)
  end

  test "CA2: confirm=false and non-boolean values do not confirm" do
    [ false, "false", "1", "yes", "" ].each do |value|
      remove(@device, confirm: value)

      assert_response :unprocessable_entity, "confirm=#{value.inspect}"
      assert_equal "DEVICE_REMOVAL_NEEDS_CONFIRMATION", json.dig("errors", 0, "code"), "confirm=#{value.inspect}"
      assert Device.exists?(@device.id), "confirm=#{value.inspect}"
    end
  end

  test "CA2: a device that is in maps needs confirmation and lists the maps count" do
    bare = build_device(name: "So no mapa", hostname: "so-mapa", management_ip: "10.1.1.1")
    map = build_map("Mapa unico")
    build_node(map, "No", mappable: bare)

    remove(bare)

    assert_response :unprocessable_entity
    assert_equal "DEVICE_REMOVAL_NEEDS_CONFIRMATION", json.dig("errors", 0, "code")
    assert_equal 1, impact_from(json).fetch("maps").size
    assert MapNode.exists?(mappable: bare)
  end

  test "RN2: a device with no impact is deleted even without confirm" do
    bare = build_device(name: "Sem nada", hostname: "sem-nada", management_ip: "10.2.2.2")

    remove(bare)

    assert_response :ok
    assert_not Device.exists?(bare.id)
  end

  # ---- CA3 ----

  test "CA3: deleting a device in N maps removes its nodes and children in one go, keeps cables with null endpoints" do
    build_map_dependencies(map_count: 2)
    node_ids = @device_nodes.map(&:id)

    remove(@device, confirm: true)

    assert_response :ok
    assert_equal 0, MapNode.where(id: node_ids).count
    assert_equal 0, MapNodeItem.where(map_node_id: node_ids).count
    assert_equal 0, MapMonitoringBinding.where(map_node_id: node_ids).count
    assert_equal 0, MapEdge.where(id: @edges.map(&:id)).count
    @other_nodes.each { |node| assert MapNode.exists?(node.id), "nó de outro equipamento deve permanecer" }
    @cables.each do |cable|
      cable.reload
      assert_nil cable.source_node_id
      assert_not_nil cable.target_node_id
    end
    assert_equal 2, json.dig("data", "impact", "cables_left_without_endpoint")
    assert_equal 2, json.dig("data", "impact", "maps").size
  end

  test "CA3: cables whose target is the removed node are also left without that endpoint" do
    build_map_dependencies(map_count: 1)
    reverse = build_cable(@maps.first, @other_nodes.first, @device_nodes.first)

    remove(@device, confirm: true)

    assert_response :ok
    reverse.reload
    assert_not_nil reverse.source_node_id
    assert_nil reverse.target_node_id
  end

  # ---- CA4 ----

  test "CA4: a failure in the middle of the cascade deletes nothing and answers in pt-BR in the envelope" do
    build_map_dependencies(map_count: 1)
    force_failure_on_device_delete

    remove(@device, confirm: true)

    assert_includes [ 422, 500 ], response.status
    assert json["errors"].is_a?(Array) && json["errors"].any?, "erro deve vir no envelope"
    detail = json.dig("errors", 0, "detail").to_s
    assert detail.present?
    assert_no_match ENGLISH_RAILS_TEXT, detail
    assert_no_match(/violates|PG::|RAISE|device_replacement/i, detail)
    assert_match(/n[ãa]o|equipamento|erro|tente/i, detail)

    assert Device.exists?(@device.id)
    assert ZabbixLink.exists?(@host_link.id)
    assert ZabbixLink.exists?(@interface_link.id)
    assert DeviceInterface.exists?(@interface.id)
    assert_equal 1, MapNode.where(id: @device_nodes.map(&:id)).count
    assert_equal 1, MapNodeItem.where(map_node_id: @device_nodes.first.id).count
    assert_equal 1, MapEdge.where(id: @edges.first.id).count
    assert_equal @device_nodes.first.id, @cables.first.reload.source_node_id
  end

  # ---- CA5 ----

  test "CA5: removal_impact lists maps, zabbix links, interfaces, network_links and cables" do
    build_map_dependencies(map_count: 2)
    other = build_device(name: "Vizinho", hostname: "vizinho", management_ip: "10.3.3.3")
    insert_network_link(@org, source_device_id: @device.id, target_device_id: other.id)

    impact(@device)

    assert_response :ok
    data = json.fetch("data")
    assert_equal @device.id, data["device_id"]
    assert_equal true, data["has_dependencies"]
    assert_equal @maps.map(&:id).sort, data["maps"].map { |m| m["id"] }.sort
    assert_equal @maps.map(&:name).sort, data["maps"].map { |m| m["name"] }.sort
    assert_equal [ 1, 1 ], data["maps"].map { |m| m["node_count"] }
    assert_equal({ "device" => 1, "interfaces" => 1 }, data["zabbix_links"])
    assert_equal 1, data["interfaces"]
    assert_equal 1, data["network_links"]
    assert_equal 2, data["cables_left_without_endpoint"]
    assert Device.exists?(@device.id), "removal_impact é somente leitura"
  end

  test "CA5: a bare device has no dependencies" do
    bare = build_device(name: "Sem nada", hostname: "sem-nada", management_ip: "10.2.2.2")

    impact(bare)

    assert_response :ok
    data = json.fetch("data")
    assert_equal false, data["has_dependencies"]
    assert_equal [], data["maps"]
    assert_equal({ "device" => 0, "interfaces" => 0 }, data["zabbix_links"])
    assert_equal 0, data["interfaces"]
    assert_equal 0, data["network_links"]
    assert_equal 0, data["cables_left_without_endpoint"]
  end

  # ---- CA6 / CA15: RBAC ----

  test "CA6: a device from another organization is 404 on removal_impact and DELETE, and survives" do
    foreign = build_device(name: "Alheio", org: @other_org, hostname: "alheio", management_ip: "10.8.8.8")

    get "/api/v1/devices/#{foreign.id}/removal_impact", params: { organization_id: @other_org.id }, headers: auth_for(:editor)
    assert_includes [ 403, 404, 503 ], response.status
    get "/api/v1/devices/#{foreign.id}/removal_impact", params: { organization_id: @org.id }, headers: auth_for(:editor)
    assert_response :not_found

    delete "/api/v1/devices/#{foreign.id}", params: { organization_id: @org.id, confirm: true }, headers: auth_for(:editor), as: :json
    assert_response :not_found
    assert Device.exists?(foreign.id)
  end

  test "CA6: the foreign organization's editor cannot reach this organization's device" do
    get "/api/v1/devices/#{@device.id}/removal_impact", params: { organization_id: @other_org.id }, headers: auth_for(:foreign)
    assert_response :not_found
    delete "/api/v1/devices/#{@device.id}", params: { organization_id: @other_org.id, confirm: true }, headers: auth_for(:foreign), as: :json
    assert_response :not_found

    assert Device.exists?(@device.id)
    assert ZabbixLink.exists?(@host_link.id)
  end

  test "CA6: a viewer gets 403 on removal_impact and DELETE and nothing is deleted" do
    impact(@device, role: :viewer)
    assert_response :forbidden
    assert_equal "FORBIDDEN", json["code"]

    remove(@device, role: :viewer, confirm: true)
    assert_response :forbidden
    assert_equal "FORBIDDEN", json["code"]
    assert Device.exists?(@device.id)
    assert ZabbixLink.exists?(@host_link.id)
  end

  test "CA6: anonymous gets 401 on removal_impact and DELETE" do
    get "/api/v1/devices/#{@device.id}/removal_impact", params: { organization_id: @org.id }
    assert_response :unauthorized

    delete "/api/v1/devices/#{@device.id}", params: { organization_id: @org.id, confirm: true }, as: :json
    assert_response :unauthorized
    assert Device.exists?(@device.id)
  end

  # ---- CA18 ----

  test "CA18: network_links where the device is source or target are removed with confirm and do not block the delete" do
    other = build_device(name: "Vizinho", hostname: "vizinho", management_ip: "10.3.3.3")
    insert_network_link(@org, source_device_id: @device.id, target_device_id: other.id)
    insert_network_link(@org, source_device_id: other.id, target_device_id: @device.id)
    insert_network_link(@org, source_device_id: other.id, target_device_id: nil)

    remove(@device, confirm: true)

    assert_response :ok
    assert_not Device.exists?(@device.id)
    assert_equal 0, network_links_count(@device.id)
    assert_equal 1, network_links_count(other.id), "link que não envolve o equipamento permanece"
    assert_equal 2, json.dig("data", "impact", "network_links")
  end

  test "CA18: without confirm the 422 reports meta.impact.network_links and keeps the rows" do
    bare = build_device(name: "So link", hostname: "so-link", management_ip: "10.4.4.4")
    other = build_device(name: "Vizinho", hostname: "vizinho", management_ip: "10.3.3.3")
    insert_network_link(@org, source_device_id: bare.id, target_device_id: other.id)
    insert_network_link(@org, source_device_id: other.id, target_device_id: bare.id)

    remove(bare)

    assert_response :unprocessable_entity
    assert_equal "DEVICE_REMOVAL_NEEDS_CONFIRMATION", json.dig("errors", 0, "code")
    assert_equal 2, impact_from(json)["network_links"]
    assert_equal 2, network_links_count(bare.id)
    assert Device.exists?(bare.id)
  end

  test "CA18: a cable whose network_link_id points to a removed network_link is kept, with network_link_id nil and no endpoint" do
    build_map_dependencies(map_count: 1)
    other = build_device(name: "Vizinho", hostname: "vizinho", management_ip: "10.3.3.3")
    link_id = insert_network_link(@org, source_device_id: @device.id, target_device_id: other.id)
    cable = @cables.first
    cable.update_column(:network_link_id, link_id)

    remove(@device, confirm: true)

    assert_response :ok
    assert_not Device.exists?(@device.id)
    assert_equal 0, network_links_count(@device.id)
    cable.reload
    assert_nil cable.network_link_id
    assert_nil cable.source_node_id
    assert_not_nil cable.target_node_id
  end

  private

  # Trigger no DELETE de devices: a cascata inteira já rodou quando ele estoura, então só uma
  # transação única desfaz o resto. O DDL é revertido junto com a transação do teste.
  def force_failure_on_device_delete
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE FUNCTION device_replacement_test_fail() RETURNS trigger AS $$
      BEGIN RAISE EXCEPTION 'device_replacement_test_forced_failure'; END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER device_replacement_test_fail BEFORE DELETE ON devices
        FOR EACH ROW EXECUTE FUNCTION device_replacement_test_fail();
    SQL
  end
end
