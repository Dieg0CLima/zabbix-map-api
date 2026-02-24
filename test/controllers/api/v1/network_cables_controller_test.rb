require "test_helper"

class Api::V1::NetworkCablesControllerTest < ActionDispatch::IntegrationTest
  test "create accepts pop external ids and returns pop external ids in payload" do
    organization = Organization.create!(name: "Org Cable API")
    user = User.create!(email: "cable.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable API", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin", lat: -23.1, lng: -46.1, color: "#7c3aed")
    target_pop = network_map.map_pops.create!(name: "POP Destino", external_id: "pop-target", lat: -23.2, lng: -46.2, color: "#7c3aed")

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

    post "/api/v1/network_maps/#{network_map.id}/network_cables", params: {
      network_cable: {
        source_pop_id: source_pop.external_id,
        target_pop_id: target_pop.external_id,
        cable_type: "logical",
        status: "unknown"
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    payload = response.parsed_body.fetch("data")
    assert_equal source_pop.external_id, payload["source_pop_id"]
    assert_equal target_pop.external_id, payload["target_pop_id"]
  end
end
