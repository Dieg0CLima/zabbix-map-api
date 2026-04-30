require "test_helper"

class Api::V1::CableFusionDiagramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Fusion")
    @user = User.create!(email: "fusion.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: @user, organization: @organization, role: "editor")

    @network_map = @organization.network_maps.create!(name: "Mapa Fusion", source_type: "manual")
    @source_pop = @network_map.map_pops.create!(name: "POP Origem", external_id: "pop-origin", lat: -23.1, lng: -46.1, color: "#7c3aed")
    @cable = @network_map.network_cables.create!(source_pop: @source_pop, status: "planned", label: "Fibra Fusion")
    @cable.network_cable_points.create!(position: 0, x: -23.1, y: -46.1)
    @cable.network_cable_points.create!(position: 1, x: -23.2, y: -46.2)

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "Password!123",
        organization_id: @organization.id
      }
    }, as: :json

    @auth_header = response.headers["Authorization"]
  end

  test "show lazily creates fusion diagram" do
    get "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram", params: {
      organization_id: @organization.id
    }, headers: auth_headers, as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal @cable.id, data["network_cable_id"]
    assert_equal "draft", data["status"]
    assert_equal [], data["nodes"]
  end

  test "update persists draft structure and returns validation output" do
    put "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram", params: {
      organization_id: @organization.id,
      fusion_diagram: {
        nodes: [
          { client_id: "node-1", type: "dio", label: "DIO A", x: 10, y: 20, rotation: 0 }
        ],
        ports: [
          { client_id: "port-in", node_client_id: "node-1", name: "IN-01", port_type: "fiber_in", capacity: 1, occupancy_limit: 1 },
          { client_id: "port-out", node_client_id: "node-1", name: "OUT-01", port_type: "fiber_out", capacity: 1, occupancy_limit: 1 }
        ],
        links: [
          { client_id: "link-1", source_port_client_id: "port-in", target_port_client_id: "port-out", link_kind: "splice", fiber_side: "a", fiber_number: 1 }
        ]
      }
    }, headers: auth_headers, as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal "draft", data["status"]
    assert_equal true, data.dig("validation", "is_valid")
    assert_equal 1, data["nodes"].size
    assert_equal 2, data["ports"].size
    assert_equal 1, data["links"].size
  end

  test "validate reports conflicts for duplicated fiber reference" do
    diagram = CableFusion::LoadDiagram.new(cable: @cable).call
    node = diagram.nodes.create!(node_type: "dio", label: "DIO", x: 1, y: 1, rotation: 0)
    p1 = node.ports.create!(name: "P1", port_type: "fiber_in", capacity: 1, occupancy_limit: 2)
    p2 = node.ports.create!(name: "P2", port_type: "fiber_out", capacity: 1, occupancy_limit: 2)
    p3 = node.ports.create!(name: "P3", port_type: "fiber_in", capacity: 1, occupancy_limit: 2)
    diagram.links.create!(source_port: p1, target_port: p2, link_kind: "splice", fiber_side: "a", fiber_number: 1, status: "draft")
    diagram.links.create!(source_port: p3, target_port: p2, link_kind: "splice", fiber_side: "a", fiber_number: 1, status: "draft")

    post "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram/validate", params: {
      organization_id: @organization.id
    }, headers: auth_headers, as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal false, data.dig("validation", "is_valid")
    assert_includes data.dig("validation", "errors").map { |e| e["code"] }, "fiber_ref_conflict"
  end

  test "publish creates snapshot and marks diagram as ready" do
    put "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram", params: {
      organization_id: @organization.id,
      fusion_diagram: {
        nodes: [
          { client_id: "node-1", type: "dio", label: "DIO A", x: 10, y: 20, rotation: 0 }
        ],
        ports: [
          { client_id: "port-in", node_client_id: "node-1", name: "IN-01", port_type: "fiber_in", capacity: 1, occupancy_limit: 1 },
          { client_id: "port-out", node_client_id: "node-1", name: "OUT-01", port_type: "fiber_out", capacity: 1, occupancy_limit: 1 }
        ],
        links: [
          { client_id: "link-1", source_port_client_id: "port-in", target_port_client_id: "port-out", link_kind: "splice", fiber_side: "a", fiber_number: 1 }
        ]
      }
    }, headers: auth_headers, as: :json
    assert_response :ok

    post "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram/publish", params: {
      organization_id: @organization.id,
      reason: "first publish"
    }, headers: auth_headers, as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal "ready", data["status"]
    assert_equal 1, data["version"]

    get "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram/snapshots", params: {
      organization_id: @organization.id
    }, headers: auth_headers, as: :json

    assert_response :ok
    snapshots = response.parsed_body.fetch("data")
    assert_equal 1, snapshots.size
    assert_equal true, snapshots.first["published"]
  end

  test "restore snapshot rewrites draft from selected version" do
    diagram = CableFusion::LoadDiagram.new(cable: @cable).call
    node = diagram.nodes.create!(node_type: "dio", label: "Original", x: 1, y: 1, rotation: 0)
    p1 = node.ports.create!(name: "P1", port_type: "fiber_in", capacity: 1, occupancy_limit: 1)
    p2 = node.ports.create!(name: "P2", port_type: "fiber_out", capacity: 1, occupancy_limit: 1)
    diagram.links.create!(source_port: p1, target_port: p2, link_kind: "splice", status: "draft")
    diagram.update!(version: 1)
    snapshot = CableFusion::CreateSnapshot.new(diagram:, actor: @user, reason: "baseline", published: true).call

    put "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram", params: {
      organization_id: @organization.id,
      fusion_diagram: { nodes: [], ports: [], links: [] }
    }, headers: auth_headers, as: :json
    assert_response :ok

    post "/api/v1/network_maps/#{@network_map.id}/network_cables/#{@cable.id}/fusion_diagram/snapshots/#{snapshot.id}/restore", params: {
      organization_id: @organization.id
    }, headers: auth_headers, as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal 1, data["nodes"].size
    assert_equal 2, data["ports"].size
    assert_equal 1, data["links"].size
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
