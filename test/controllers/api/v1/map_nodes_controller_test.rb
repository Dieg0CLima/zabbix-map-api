require "test_helper"

class Api::V1::MapNodesControllerTest < ActionDispatch::IntegrationTest
  test "create accepts map_pop_id as pop external_id" do
    organization = Organization.create!(name: "Org Node API")
    user = User.create!(email: "node.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa API", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP API", external_id: "pop-api", lat: -23.0, lng: -46.0, color: "#7c3aed")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    assert_response :ok

    auth_header = response.headers["Authorization"]
    assert auth_header.present?

    post "/api/v1/network_maps/#{network_map.id}/map_nodes", params: {
      map_node: {
        label: "Router API",
        node_kind: "router",
        x: 100,
        y: 120,
        map_pop_id: pop.external_id
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    created_node = network_map.map_nodes.order(:id).last
    assert_equal pop.id, created_node.map_pop_id
  end


  test "create persists zabbix_host_id when host belongs to map connection" do
    organization = Organization.create!(name: "Org Node Host API")
    user = User.create!(email: "node.host.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    connection = organization.zabbix_connections.create!(
      name: "Conn Node",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.local"
    )
    host = connection.zabbix_hosts.create!(hostid: "10105", name: "OLT-1")
    network_map = organization.network_maps.create!(name: "Mapa API Host", source_type: "manual", zabbix_connection: connection)

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    assert_response :ok

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/map_nodes", params: {
      map_node: {
        label: "Router API",
        node_kind: "router",
        x: 100,
        y: 120,
        zabbix_host_id: host.id
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    created_node = network_map.map_nodes.order(:id).last
    assert_equal host.id, created_node.zabbix_host_id
  end

end
