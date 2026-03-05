require "test_helper"

class Api::V1::SitesControllerTest < ActionDispatch::IntegrationTest
  test "creates site" do
    organization = Organization.create!(name: "Org Site API")
    user = User.create!(email: "site.editor@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user:, organization:, role: "editor")

    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: organization.id } }, as: :json
    auth_header = response.headers["Authorization"]

    post "/api/v1/sites", params: { site: { name: "POP São Paulo", status: "active" }, organization_id: organization.id }, headers: { "Authorization" => auth_header }, as: :json

    assert_response :created
    assert_equal "POP São Paulo", response.parsed_body.dig("data", "name")
  end
end
