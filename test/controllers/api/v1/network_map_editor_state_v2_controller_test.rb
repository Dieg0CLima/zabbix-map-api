require "test_helper"

class Api::V1::NetworkMapEditorStateV2ControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "editorstate@example.com", password: "password", password_confirmation: "password")
    @organization = Organization.create!(name: "Org Editor", slug: "org-editor")
    Membership.create!(user: @user, organization: @organization, role: "admin")
    @network_map = NetworkMap.create!(organization: @organization, name: "Editor Map")
    @site = Site.create!(organization: @organization, name: "Site A", slug: "site-a")
    @device = Device.create!(organization: @organization, site: @site, name: "SW-01", role: "switch", status: "active")
    @network_map.map_nodes.create!(mappable: @site, label: @site.name, node_kind: "gateway", x: 1, y: 1, lat: 1, lng: 1, icon: "pi-building", color: "#111111", size: 30)
    @network_map.map_nodes.create!(mappable: @device, label: @device.name, node_kind: "switch", x: 2, y: 2, lat: 2, lng: 2, icon: "pi-box", color: "#222222", size: 30)

    post "/api/v1/users/sign_in", params: { user: { email: @user.email, password: "password", organization_id: @organization.id } }
    @auth_headers = response.headers.slice("Authorization")
  end

  test "editor_state returns only site markers as renderable elements" do
    get "/api/v1/network_maps/#{@network_map.id}/editor_state", params: { organization_id: @organization.id }, headers: @auth_headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.dig("data", "elements").size
    assert_equal "Site", body.dig("data", "elements", 0, "mappable_type")
    assert_equal 1, body.dig("data", "devices").size
    assert_equal 1, body.dig("data", "sites").size
  end
end
