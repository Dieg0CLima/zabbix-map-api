require "test_helper"

class Api::V1::Users::AuthOrganizationFlowTest < ActionDispatch::IntegrationTest
  test "sign up returns created organization payload" do
    assert_difference ["User.count", "Organization.count", "Membership.count"], 1 do
      post "/api/v1/users", params: {
        user: {
          email: "new.user@example.com",
          password: "Password!123",
          password_confirmation: "Password!123",
          organization_name: "Acme Networks"
        }
      }, as: :json
    end

    assert_response :created

    payload = response.parsed_body.fetch("data")
    organization = payload.fetch("organization")

    assert_equal "new.user@example.com", payload["email"]
    assert_equal "Acme Networks", organization["name"]
    assert_equal "acme-networks", organization["slug"]
    assert_equal "admin", organization["role"]
  end

  test "sign in returns selected organization payload" do
    user = User.create!(
      email: "member@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )

    first_org = Organization.create!(name: "Org One")
    second_org = Organization.create!(name: "Org Two")

    Membership.create!(user:, organization: first_org, role: "viewer")
    Membership.create!(user:, organization: second_org, role: "editor")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123",
        organization_id: second_org.id
      }
    }, as: :json

    assert_response :ok

    payload = response.parsed_body.fetch("data")
    organization = payload.fetch("organization")

    assert_equal second_org.id, payload["org_id"]
    assert_equal second_org.id, organization["id"]
    assert_equal "Org Two", organization["name"]
    assert_equal "org-two", organization["slug"]
    assert_equal "editor", organization["role"]
  end
end
