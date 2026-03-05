require "test_helper"

class Api::V1::NetworkCablesControllerTest < ActionDispatch::IntegrationTest
  test "create accepts pop external ids, free end and returns ids plus ordered points" do
    organization = Organization.create!(name: "Org Cable API")
    user = User.create!(email: "cable.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable API", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin", lat: -23.1, lng: -46.1, color: "#7c3aed")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/network_cables", params: {
      network_cable: {
        source_pop_id: source_pop.external_id,
        target_pop_id: nil,
        cable_type: "feeder",
        status: "active",
        metadata: { fiber_count: 24 },
        points: [
          { position: 0, lat: -23.550001, lng: -46.630001 },
          { position: 1, lat: -23.560001, lng: -46.640001 }
        ]
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created

    payload = response.parsed_body.fetch("data")
    assert payload["id"].present?
    assert payload["external_id"].present?
    assert_equal source_pop.external_id, payload["source_pop_id"]
    assert_nil payload["target_pop_id"]
    assert_equal 2, payload.fetch("points").size

    created_cable = network_map.network_cables.find(payload["id"])
    created_event = created_cable.network_cable_events.order(:id).last
    assert_equal "created", created_event.event_type
    assert_equal({}, created_event.before_state)
    assert created_event.after_state.present?
  end

  test "create validates points minimum" do
    organization = Organization.create!(name: "Org Cable API 2")
    user = User.create!(email: "cable.editor2@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable API 2", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin", lat: -23.1, lng: -46.1, color: "#7c3aed")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/network_cables", params: {
      network_cable: {
        source_pop_id: source_pop.external_id,
        points: [{ position: 0, lat: -23.55, lng: -46.63 }]
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :unprocessable_entity
    error = response.parsed_body.fetch("error")
    assert_equal "invalid_points", error["code"]
    assert_equal 2, error.dig("details", "min_points")
  end

  test "create accepts network_link_id as external_id" do
    organization = Organization.create!(name: "Org Cable Link API")
    user = User.create!(email: "cable.link@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable Link API", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin-link", lat: -23.1, lng: -46.1, color: "#7c3aed")
    site = organization.sites.create!(name: "Site Link", status: "active")
    network_link = organization.network_links.create!(external_id: "link-ext", source_site: site, link_type: "fiber", status: "active")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    post "/api/v1/network_maps/#{network_map.id}/network_cables", params: {
      network_cable: {
        source_pop_id: source_pop.external_id,
        network_link_id: network_link.external_id,
        points: [
          { position: 0, lat: -23.550001, lng: -46.630001 },
          { position: 1, lat: -23.560001, lng: -46.640001 }
        ]
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :created
    assert_equal network_link.external_id, response.parsed_body.dig("data", "network_link_id")
  end
end
