require "test_helper"

class Api::V1::SitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "sites@example.com", password: "password", password_confirmation: "password")
    @organization = Organization.create!(name: "Org Sites", slug: "org-sites")
    Membership.create!(user: @user, organization: @organization, role: "admin")

    post "/api/v1/users/sign_in", params: { user: { email: @user.email, password: "password", organization_id: @organization.id } }
    @auth_headers = response.headers.slice("Authorization")
  end

  test "creates site with consistent envelope" do
    post "/api/v1/sites", params: {
      organization_id: @organization.id,
      site: { name: "POP Centro", city: "São Paulo" }
    }, headers: @auth_headers

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal [], body["errors"]
    assert_equal "POP Centro", body.dig("data", "site", "name")
    assert_equal({}, body["meta"])
  end
end
