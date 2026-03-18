require "test_helper"

class Api::V1::MapElementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Elements Test #{rand(10_000)}")
    @user = User.create!(
      email: "elem.editor.#{rand(9999)}@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )
    Membership.create!(user: @user, organization: @organization, role: "editor")
    @network_map = @organization.network_maps.create!(name: "Mapa Elements", source_type: "manual")
    @site = @organization.sites.create!(name: "Site SP")
    @device = @organization.devices.create!(name: "Router Core")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "Password!123",
        organization_id: @organization.id
      }
    }, as: :json

    @auth_header = response.headers["Authorization"]
  end

  test "index returns elements for the map" do
    @network_map.map_elements.create!(mappable: @site, lat: -23.55, lng: -46.63)
    @network_map.map_elements.create!(mappable: @device, lat: -23.56, lng: -46.64)

    get "/api/v1/network_maps/#{@network_map.id}/map_elements",
        params: { organization_id: @organization.id },
        headers: { "Authorization" => @auth_header },
        as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal 2, data.length
  end

  test "index filters by type" do
    @network_map.map_elements.create!(mappable: @site, lat: -23.55, lng: -46.63)
    @network_map.map_elements.create!(mappable: @device, lat: -23.56, lng: -46.64)

    get "/api/v1/network_maps/#{@network_map.id}/map_elements",
        params: { type: "Site", organization_id: @organization.id },
        headers: { "Authorization" => @auth_header },
        as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal 1, data.length
    assert_equal "Site", data.first["mappable_type"]
  end

  test "create adds a Site element to the map" do
    post "/api/v1/network_maps/#{@network_map.id}/map_elements",
         params: {
           map_element: {
             mappable_type: "Site",
             mappable_id:   @site.id,
             lat:           -23.55,
             lng:           -46.63,
             color_override: "#ff0000",
             label_override: "Site Custom"
           },
           organization_id: @organization.id
         },
         headers: { "Authorization" => @auth_header },
         as: :json

    assert_response :created
    data = response.parsed_body.fetch("data")
    assert_equal "Site", data["mappable_type"]
    assert_equal @site.id, data["mappable_id"]
    assert_equal "#ff0000", data["color_override"]
    assert_equal "Site Custom", data["label_override"]
    assert_equal "Site Custom", data["label"]

    # entity data is embedded
    assert_equal "Site SP", data.dig("entity", "name")
  end

  test "create adds a Device element to the map" do
    post "/api/v1/network_maps/#{@network_map.id}/map_elements",
         params: {
           map_element: {
             mappable_type: "Device",
             mappable_id:   @device.id,
             lat:           -23.56,
             lng:           -46.64
           },
           organization_id: @organization.id
         },
         headers: { "Authorization" => @auth_header },
         as: :json

    assert_response :created
    data = response.parsed_body.fetch("data")
    assert_equal "Device", data["mappable_type"]
    assert_equal @device.id, data["mappable_id"]
    assert_equal "Router Core", data["label"]
  end

  test "create prevents adding same entity twice to a map" do
    @network_map.map_elements.create!(mappable: @site, lat: -23.55, lng: -46.63)

    post "/api/v1/network_maps/#{@network_map.id}/map_elements",
         params: {
           map_element: {
             mappable_type: "Site",
             mappable_id:   @site.id,
             lat:           0,
             lng:           0
           },
           organization_id: @organization.id
         },
         headers: { "Authorization" => @auth_header },
         as: :json

    assert_response :unprocessable_entity
  end

  test "update changes only visual attributes" do
    element = @network_map.map_elements.create!(
      mappable: @site, lat: -23.55, lng: -46.63
    )

    patch "/api/v1/network_maps/#{@network_map.id}/map_elements/#{element.external_id}",
          params: {
            map_element: {
              lat:           -24.0,
              lng:           -47.0,
              color_override: "#00ff00",
              label_override: "Updated Label",
              collapsed:     true
            },
            organization_id: @organization.id
          },
          headers: { "Authorization" => @auth_header },
          as: :json

    assert_response :ok
    data = response.parsed_body.fetch("data")
    assert_equal "#00ff00", data["color_override"]
    assert_equal "Updated Label", data["label_override"]
    assert_equal true, data["collapsed"]
    # Entity name is unchanged
    assert_equal "Site SP", data.dig("entity", "name")
  end

  test "destroy removes the element from the map" do
    element = @network_map.map_elements.create!(mappable: @site, lat: -23.55, lng: -46.63)

    delete "/api/v1/network_maps/#{@network_map.id}/map_elements/#{element.external_id}",
           params: { organization_id: @organization.id },
           headers: { "Authorization" => @auth_header },
           as: :json

    assert_response :no_content
    assert_not MapElement.exists?(element.id)
    # Site should still exist
    assert Site.exists?(@site.id)
  end
end
