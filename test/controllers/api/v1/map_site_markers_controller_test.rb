require "test_helper"

class Api::V1::MapSiteMarkersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "mapsites@example.com", password: "password", password_confirmation: "password")
    @organization = Organization.create!(name: "Org Maps", slug: "org-maps")
    Membership.create!(user: @user, organization: @organization, role: "admin")
    @site = Site.create!(organization: @organization, name: "POP A", slug: "pop-a")
    @network_map = NetworkMap.create!(organization: @organization, name: "Main Map")

    post "/api/v1/users/sign_in", params: { user: { email: @user.email, password: "password", organization_id: @organization.id } }
    @auth_headers = response.headers.slice("Authorization")
  end

  test "attaches an existing site to the map" do
    post "/api/v1/network_maps/#{@network_map.id}/site_markers", params: {
      organization_id: @organization.id,
      site_id: @site.id,
      position: { lat: 10, lng: 20 }
    }, headers: @auth_headers

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Site", body.dig("data", "mappable_type")
    assert_equal @site.id, body.dig("data", "mappable_id")
  end

  test "bulk_create attaches several sites, keeping their nested position" do
    other = Site.create!(organization: @organization, name: "POP B", slug: "pop-b")

    post "/api/v1/network_maps/#{@network_map.id}/site_markers/bulk_create", params: {
      organization_id: @organization.id,
      items: [
        { site_id: @site.id, position: { lat: 10, lng: 20 } },
        { site_id: other.id, position: { lat: 11.5, lng: 21.5 } }
      ]
    }, headers: @auth_headers, as: :json

    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_equal [], data["errors"], "nested position must not be lost (it used to fail with 'X can't be blank')"
    assert_equal 2, data["successes"].size
    assert_equal 2, @network_map.map_nodes.where(mappable_type: "Site").count
    node = @network_map.map_nodes.find_by!(mappable: other)
    assert_in_delta 11.5, node.lat.to_f, 0.0001
    assert_in_delta 21.5, node.lng.to_f, 0.0001
  end

  test "bulk_create reports items that fail instead of hiding them" do
    post "/api/v1/network_maps/#{@network_map.id}/site_markers/bulk_create", params: {
      organization_id: @organization.id,
      items: [{ site_id: 0, position: { lat: 1, lng: 2 } }]
    }, headers: @auth_headers, as: :json

    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_equal 0, data["successes"].size
    assert_equal 1, data["errors"].size
  end

  test "updates a marker's label, colour and position from a flat body" do
    post "/api/v1/network_maps/#{@network_map.id}/site_markers", params: {
      organization_id: @organization.id, site_id: @site.id, position: { lat: 10, lng: 20 }
    }, headers: @auth_headers
    marker_id = JSON.parse(response.body).dig("data", "id")

    patch "/api/v1/network_maps/#{@network_map.id}/site_markers/#{marker_id}", params: {
      organization_id: @organization.id, label_override: "Rótulo", color_override: "#ff0000", position: { lat: 11, lng: 21 }
    }, headers: @auth_headers, as: :json

    assert_response :success
    node = @network_map.map_nodes.find(marker_id)
    assert_equal "Rótulo", node.label_override
    assert_equal "#ff0000", node.color
    assert_in_delta 11.0, node.lat.to_f, 0.0001
  end
end
