require "test_helper"

class Api::V1::MapPopsControllerTest < ActionDispatch::IntegrationTest
  test "create returns external id as id and persists the same external_id" do
    organization = Organization.create!(name: "Org POP Test")
    user = User.create!(
      email: "pop.editor@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa POP", source_type: "manual")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/map_pops", params: {
      map_pop: {
        name: "POP Centro",
        lat: -23.543198,
        lng: -46.627956,
        color: "#c64600"
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    payload = response.parsed_body.fetch("data")

    assert_equal payload["external_id"], payload["id"]
    assert_match(/\Apop-/, payload["external_id"])

    saved_pop = network_map.map_pops.find_by!(external_id: payload["external_id"])
    assert_equal payload["external_id"], saved_pop.external_id
  end

  test "destroy returns validation error when pop has dependencies" do
    organization = Organization.create!(name: "Org POP Dep")
    user = User.create!(email: "pop.dep@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")
    network_map = organization.network_maps.create!(name: "Mapa POP Dep", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP Centro", external_id: "pop-centro", lat: -23.1, lng: -46.1, color: "#7c3aed")
    network_map.map_nodes.create!(external_id: "node-1", map_pop: pop, label: "OLT", node_kind: "olt", x: -23.1, y: -46.1, lat: -23.1, lng: -46.1, icon: "pi-server", color: "#2563eb", size: 30)

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    delete "/api/v1/network_maps/#{network_map.id}/map_pops/#{pop.external_id}", params: {
      organization_id: organization.id
    }, headers: {
      "Authorization" => response.headers["Authorization"]
    }, as: :json

    assert_response :unprocessable_entity
    assert_equal "VALIDATION_ERROR", response.parsed_body["code"]
  end
end
