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
end
