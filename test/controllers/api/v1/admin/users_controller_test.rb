require "test_helper"

class Api::V1::Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Admin Users")
    @organization_b = Organization.create!(name: "Org Admin Users B")

    @admin_user = User.create!(
      email: "admin.users@example.com",
      password: "Password!123",
      password_confirmation: "Password!123",
      admin: true
    )
    Membership.create!(user: @admin_user, organization: @organization, role: "admin")

    @local_user = User.create!(
      email: "local.user@example.com",
      password: "Password!123",
      password_confirmation: "Password!123",
      authentication_source: "local"
    )
    Membership.create!(user: @local_user, organization: @organization, role: "viewer")
    Membership.create!(user: @local_user, organization: @organization_b, role: "editor")

    @ldap_user = User.create!(
      email: "ldap.user@example.com",
      password: "Password!123",
      password_confirmation: "Password!123",
      authentication_source: "ldap"
    )
    Membership.create!(user: @ldap_user, organization: @organization, role: "viewer")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @admin_user.email,
        password: "Password!123"
      }
    }, as: :json

    @auth_headers = { "Authorization" => response.headers["Authorization"] }
  end

  test "index lists users with auth source and memberships" do
    get "/api/v1/admin/users", headers: @auth_headers, as: :json

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    local_payload = payload.find { |entry| entry["id"] == @local_user.id }
    ldap_payload = payload.find { |entry| entry["id"] == @ldap_user.id }

    assert_equal "local", local_payload["authentication_source"]
    assert_equal false, local_payload["ldap_managed"]
    assert_equal "ldap", ldap_payload["authentication_source"]
    assert_equal true, ldap_payload["ldap_managed"]

    memberships = local_payload.fetch("memberships")
    assert_equal 2, memberships.size
    assert_includes memberships, { "organization_id" => @organization.id, "role" => "viewer" }
    assert_includes memberships, { "organization_id" => @organization_b.id, "role" => "editor" }
  end

  test "update edits email and membership role" do
    patch "/api/v1/admin/users/#{@local_user.id}", params: {
      user: {
        email: "local.user.updated@example.com",
        membership_role: "editor"
      }
    }, headers: @auth_headers, as: :json

    assert_response :ok
    @local_user.reload
    assert_equal "local.user.updated@example.com", @local_user.email
    assert_equal "editor", @local_user.memberships.order(:id).first.role
  end

  test "reset_password updates local user password" do
    patch "/api/v1/admin/users/#{@local_user.id}/reset_password", params: {
      user: {
        password: "NewPassword!123",
        password_confirmation: "NewPassword!123"
      }
    }, headers: @auth_headers, as: :json

    assert_response :ok
    @local_user.reload
    assert @local_user.valid_password?("NewPassword!123")
  end

  test "reset_password rejects ldap users" do
    patch "/api/v1/admin/users/#{@ldap_user.id}/reset_password", params: {
      user: {
        password: "NewPassword!123",
        password_confirmation: "NewPassword!123"
      }
    }, headers: @auth_headers, as: :json

    assert_response :unprocessable_entity
    assert_equal "INVALID_OPERATION", response.parsed_body["code"]
  end
end
