require "test_helper"

class Api::V1::Users::AuthOrganizationFlowTest < ActionDispatch::IntegrationTest
  test "sign up returns created organization payload" do
    assert_difference [ "User.count", "Organization.count", "Membership.count" ], 1 do
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
    assert response.headers["Authorization"].present?

    payload = response.parsed_body.fetch("data")
    organization = payload.fetch("organization")

    assert_equal second_org.id, payload["org_id"]
    assert_equal second_org.id, organization["id"]
    assert_equal "Org Two", organization["name"]
    assert_equal "org-two", organization["slug"]
    assert_equal "editor", organization["role"]
  end

  test "sign in resolves organization in single-tenant mode without organization_id" do
    user = User.create!(
      email: "single-tenant@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )

    org = Organization.create!(name: "Single Tenant Org")
    Membership.create!(user:, organization: org, role: "admin")

    original_mode = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = "single"

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123"
      }
    }, as: :json

    assert_response :ok
    assert response.headers["Authorization"].present?

    payload = response.parsed_body.fetch("data")
    assert_equal org.id, payload["org_id"]
  ensure
    ENV["TENANCY_MODE"] = original_mode
  end

  test "sign in authenticates via ldap when enabled" do
    user = User.create!(
      email: "ldap.user@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )
    org = Organization.create!(name: "LDAP Org")
    Membership.create!(user:, organization: org, role: "viewer")

    ldap_config = Struct.new(:enabled?, :fallback_to_database_auth?).new(true, false)
    auth_result = Struct.new(:success?, :email, :name, :login).new(true, user.email, "LDAP User", "ldap.user")

    authenticator = Struct.new(:result) { def call(**_kwargs) = result }.new(auth_result)
    resolver = Struct.new(:user) { def call(**_kwargs) = user }.new(user)

    Auth::Ldap::Config.stub :current, ldap_config do
      authenticator_factory = ->(**_kwargs) { authenticator }
      resolver_factory = ->(**_kwargs) { resolver }
      Auth::Ldap::Authenticator.stub :new, authenticator_factory do
        Auth::Ldap::UserResolver.stub :new, resolver_factory do
          post "/api/v1/users/sign_in", params: {
            user: {
              login: "ldap.user",
              password: "Password!123",
              organization_id: org.id
            }
          }, as: :json
        end
      end
    end

    assert_response :ok
    assert response.headers["Authorization"].present?
    payload = response.parsed_body.fetch("data")
    assert_equal user.email, payload["email"]
    assert_equal org.id, payload["org_id"]
  end

  test "sign in via ldap works without email attribute using login mapping in single-tenant mode" do
    org = Organization.create!(name: "LDAP Single Org")
    ldap_user = User.create!(
      email: "ldap-diego.lima@local.invalid",
      password: "Password!123",
      password_confirmation: "Password!123"
    )
    Membership.create!(user: ldap_user, organization: org, role: "viewer")

    ldap_config = Struct.new(:enabled?, :fallback_to_database_auth?).new(true, false)
    auth_result = Struct.new(:success?, :email, :name, :login).new(true, nil, "Diego Lima", "diego.lima")

    authenticator = Struct.new(:result) { def call(**_kwargs) = result }.new(auth_result)
    resolver = Struct.new(:user) { def call(**_kwargs) = user }.new(ldap_user)

    original_mode = ENV["TENANCY_MODE"]
    ENV["TENANCY_MODE"] = "single"

    Auth::Ldap::Config.stub :current, ldap_config do
      authenticator_factory = ->(**_kwargs) { authenticator }
      resolver_factory = ->(**_kwargs) { resolver }
      Auth::Ldap::Authenticator.stub :new, authenticator_factory do
        Auth::Ldap::UserResolver.stub :new, resolver_factory do
          post "/api/v1/users/sign_in", params: {
            user: {
              login: "diego.lima",
              password: "Password!123"
            }
          }, as: :json
        end
      end
    end

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    assert_equal ldap_user.email, payload["email"]
    assert_equal org.id, payload["org_id"]
  ensure
    ENV["TENANCY_MODE"] = original_mode
  end

  test "sign in returns unauthorized when ldap fails and fallback is disabled" do
    ldap_config = Struct.new(:enabled?, :fallback_to_database_auth?).new(true, false)
    auth_result = Struct.new(:success?).new(false)

    authenticator = Struct.new(:result) { def call(**_kwargs) = result }.new(auth_result)

    Auth::Ldap::Config.stub :current, ldap_config do
      authenticator_factory = ->(**_kwargs) { authenticator }
      Auth::Ldap::Authenticator.stub :new, authenticator_factory do
        post "/api/v1/users/sign_in", params: {
          user: {
            email: "missing@example.com",
            password: "bad-password"
          }
        }, as: :json
      end
    end

    assert_response :unauthorized
  end
end
