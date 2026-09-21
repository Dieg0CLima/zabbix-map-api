require "test_helper"

class Api::V1::NetworkCablesControllerTest < ActionDispatch::IntegrationTest
  test "create accepts source_site_id and target_site_id through attached site nodes" do
    organization = Organization.create!(name: "Org Cable Site API")
    user = User.create!(email: "cable.site.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable Site API", source_type: "manual")
    source_site = organization.sites.create!(name: "Site Origem", slug: "site-origem")
    target_site = organization.sites.create!(name: "Site Destino", slug: "site-destino")
    source_node = network_map.map_nodes.create!(
      external_id: "site-node-origin",
      label: "Site Origem",
      node_kind: "generic",
      x: -23.55,
      y: -46.63,
      lat: -23.55,
      lng: -46.63,
      mappable: source_site
    )
    target_node = network_map.map_nodes.create!(
      external_id: "site-node-target",
      label: "Site Destino",
      node_kind: "generic",
      x: -23.56,
      y: -46.64,
      lat: -23.56,
      lng: -46.64,
      mappable: target_site
    )

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
        source_site_id: source_site.id,
        target_site_id: target_site.id,
        cable_type: "feeder",
        status: "active",
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
    assert_equal source_site.id, payload["source_site_id"]
    assert_equal target_site.id, payload["target_site_id"]
    assert_equal source_node.external_id, payload["source_node_id"]
    assert_equal target_node.external_id, payload["target_node_id"]

    created_cable = network_map.network_cables.find(payload["id"])
    assert_equal source_node.id, created_cable.source_node_id
    assert_equal target_node.id, created_cable.target_node_id
  end

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
        points: [ { position: 0, lat: -23.55, lng: -46.63 } ]
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :unprocessable_entity
    body = response.parsed_body
    error = body["errors"]&.first || body
    assert_equal "invalid_points", error["code"]
    assert_equal 2, body.dig("details", "min_points")
  end

  test "geometry remove_segment updates points and returns geometry_version" do
    organization = Organization.create!(name: "Org Cable Geometry")
    user = User.create!(email: "cable.geometry@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable Geometry", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin", lat: -23.1, lng: -46.1, color: "#7c3aed")
    cable = network_map.network_cables.create!(source_pop:, status: "planned", label: "Fibra A")
    5.times { |index| cable.network_cable_points.create!(position: index, x: index, y: index) }

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    patch "/api/v1/network_maps/#{network_map.id}/network_cables/#{cable.id}/geometry", params: {
      geometry: {
        operation: "remove_segment",
        geometry_version: 0,
        from_position: 1,
        to_position: 2
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    assert_equal 1, payload["geometry_version"]
    assert_equal 3, payload.fetch("points").size
  end

  test "geometry returns 409 for stale geometry_version" do
    organization = Organization.create!(name: "Org Cable Geometry Conflict")
    user = User.create!(email: "cable.geometry.conflict@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable Geometry Conflict", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin", lat: -23.1, lng: -46.1, color: "#7c3aed")
    cable = network_map.network_cables.create!(source_pop:, status: "planned", label: "Fibra B", metadata: { "geometry_version" => 2 })
    4.times { |index| cable.network_cable_points.create!(position: index, x: index, y: index) }

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    patch "/api/v1/network_maps/#{network_map.id}/network_cables/#{cable.id}/geometry", params: {
      geometry: {
        operation: "remove_point",
        geometry_version: 1,
        position: 2
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :conflict
    body = response.parsed_body
    assert_nil body["data"]
    assert_equal "geometry_conflict", body["code"]
    assert_equal "Geometry version conflict", body["message"]
    assert_equal "Geometry version conflict", body["error"]
    assert_equal 1, body.dig("details", "expected_version")
    assert_equal 2, body.dig("details", "current_version")
  end

  test "geometry attach_endpoint_to_pop rebinds endpoint and snaps terminal point" do
    organization = Organization.create!(name: "Org Cable Geometry Bind Pop")
    user = User.create!(email: "cable.geometry.bind.pop@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    network_map = organization.network_maps.create!(name: "Mapa Cable Geometry Bind Pop", source_type: "manual")
    source_endpoint = network_map.map_nodes.create!(
      external_id: "kmz-endpoint-source",
      label: "KMZ Endpoint Source",
      node_kind: "generic",
      x: -23.5001,
      y: -46.6001,
      lat: -23.5001,
      lng: -46.6001
    )
    cable = network_map.network_cables.create!(source_node: source_endpoint, status: "planned", label: "Fibra C")
    2.times { |index| cable.network_cable_points.create!(position: index, x: -23.5 + index, y: -46.6 + index) }
    source_pop = network_map.map_pops.create!(name: "POP Vinculo", external_id: "pop-bind", lat: -23.777, lng: -46.888, color: "#7c3aed")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: organization.id
      }
    }, as: :json

    auth_header = response.headers["Authorization"]

    patch "/api/v1/network_maps/#{network_map.id}/network_cables/#{cable.id}/geometry", params: {
      geometry: {
        operation: "attach_endpoint_to_pop",
        geometry_version: 0,
        side: "source",
        pop_id: source_pop.external_id
      },
      organization_id: organization.id
    }, headers: {
      "Authorization" => auth_header
    }, as: :json

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    first_point = payload.fetch("points").min_by { |point| point.fetch("position") }

    assert_equal source_pop.external_id, payload["source_pop_id"]
    assert_nil payload["source_node_id"]
    assert_equal source_pop.lat.to_f, first_point["lat"].to_f
    assert_equal source_pop.lng.to_f, first_point["lng"].to_f
    assert_equal 1, payload["geometry_version"]
  end
end
