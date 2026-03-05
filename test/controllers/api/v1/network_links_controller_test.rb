require "test_helper"

class Api::V1::NetworkLinksControllerTest < ActionDispatch::IntegrationTest
  test "creates network link with device external ids" do
    organization = Organization.create!(name: "Org Link API")
    source = organization.devices.create!(name: "A", external_id: "device-a", device_type: "switch", status: "active")
    target = organization.devices.create!(name: "B", external_id: "device-b", device_type: "router", status: "active")
    user = User.create!(email: "link.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: organization.id } }, as: :json
    auth_header = response.headers["Authorization"]

    post "/api/v1/network_links", params: {
      network_link: { source_device_id: source.external_id, target_device_id: target.external_id, link_type: "fiber", zabbix_item_ref: "29876" },
      organization_id: organization.id
    }, headers: { "Authorization" => auth_header }, as: :json

    assert_response :created
    assert_equal source.external_id, response.parsed_body.dig("data", "source_device_id")
  end
end
