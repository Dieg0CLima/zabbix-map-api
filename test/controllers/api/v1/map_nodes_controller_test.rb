require "test_helper"

class Api::V1::MapNodesControllerTest < ActionDispatch::IntegrationTest
  test "create attaches a site as mappable" do
    organization = Organization.create!(name: "Org Node API")
    user = User.create!(email: "node.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa API", source_type: "manual")
    site = organization.sites.create!(name: "POP API")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/nodes", params: {
      map_node: {
        mappable_type: "Site",
        mappable_id: site.id,
        x: 100,
        y: 120
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    created_node = network_map.map_nodes.order(:id).last
    assert_equal "Site", created_node.mappable_type
    assert_equal site.id, created_node.mappable_id
  end

  test "create attaches a device as mappable" do
    organization = Organization.create!(name: "Org Node Device API")
    user = User.create!(email: "node.device.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa API Device", source_type: "manual")
    device = organization.devices.create!(name: "Router API", role: "router", status: "active")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/nodes", params: {
      map_node: {
        mappable_type: "Device",
        mappable_id: device.id,
        x: 80,
        y: 95
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    created_node = network_map.map_nodes.order(:id).last
    assert_equal "Device", created_node.mappable_type
    assert_equal device.id, created_node.mappable_id
  end

  test "create rejects unsupported mappable type" do
    organization = Organization.create!(name: "Org Node Unsupported API")
    user = User.create!(email: "node.unsupported.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa API Unsupported", source_type: "manual")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/nodes", params: {
      map_node: {
        mappable_type: "MapPop",
        mappable_id: 123,
        x: 80,
        y: 95
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Unsupported mappable type", response.parsed_body.dig("errors", 0, "detail")
  end
end
