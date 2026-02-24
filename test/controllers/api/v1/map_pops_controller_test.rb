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

    assert_response :ok

    auth_header = response.headers["Authorization"]
    assert auth_header.present?

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
end
