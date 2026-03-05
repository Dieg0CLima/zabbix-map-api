require "test_helper"

class Api::V1::DevicesControllerTest < ActionDispatch::IntegrationTest
  test "creates device with site external_id" do
    organization = Organization.create!(name: "Org Device API")
    site = organization.sites.create!(name: "Site API", external_id: "site-api", status: "active")
    user = User.create!(email: "device.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: organization.id } }, as: :json
    auth_header = response.headers["Authorization"]

    post "/api/v1/devices", params: { device: { name: "OLT-SP01", site_id: site.external_id, device_type: "olt", zabbix_ref: "10084" }, organization_id: organization.id }, headers: { "Authorization" => auth_header }, as: :json

    assert_response :created
    assert_equal site.external_id, response.parsed_body.dig("data", "site_id")
  end
end
