require "test_helper"
require_relative "../../../../support/public_signup_flag"

# REQ-008 F0: public sign up (POST /api/v1/users) is off unless ALLOW_PUBLIC_SIGNUP is exactly "true"
# (trimmed, case-insensitive), read on every request. Synthetic data only (example.com).
class Api::V1::Users::PublicSignupFlagTest < ActionDispatch::IntegrationTest
  include PublicSignupFlag

  DISABLED_VALUES = [ nil, "", "   ", "false", "FALSE", "0", "1", "yes", "on", "ativo", "truee", "tru", "true1", "t", "enabled" ].freeze
  ENABLED_VALUES = [ "true", "TRUE", "True", "  true  ", "#{9.chr}true#{10.chr}" ].freeze

  def signup_params(email: nil, **extra)
    { user: { email: email || "signup.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123" }.merge(extra) }
  end

  def counts
    [ User.count, Organization.count, Membership.count ]
  end

  def assert_not_found_envelope
    assert_response :not_found
    body = response.parsed_body
    assert_equal "NOT_FOUND", body["code"]
    assert_nil body["data"]
    assert body["errors"].is_a?(Array) && body["errors"].any?, "errors must be a non-empty array"
    assert_nil response.headers["Authorization"]
  end

  # ---- CA1: strict parse ----

  test "CA1: any value other than exactly true (trimmed, case-insensitive) keeps sign up disabled" do
    DISABLED_VALUES.each do |value|
      with_public_signup(value) do
        before = counts
        post "/api/v1/users", params: signup_params(organization_name: "Org #{SecureRandom.hex(3)}"), as: :json

        assert_not_found_envelope
        assert_equal before, counts, "flag=#{value.inspect} must not create anything"
      end
    end
  end

  test "CA1: true in any case, with surrounding whitespace, enables sign up" do
    ENABLED_VALUES.each do |value|
      with_public_signup(value) do
        assert_difference "User.count", 1 do
          post "/api/v1/users", params: signup_params(organization_name: "Org #{SecureRandom.hex(3)}"), as: :json
        end
        assert_response :created, "flag=#{value.inspect}"
      end
    end
  end

  test "CA1: the flag is read on every request, not at boot" do
    with_public_signup(nil) do
      post "/api/v1/users", params: signup_params, as: :json
      assert_response :not_found

      ENV[PublicSignupFlag::KEY] = "true"
      assert_difference "User.count", 1 do
        post "/api/v1/users", params: signup_params, as: :json
      end
      assert_response :created

      ENV[PublicSignupFlag::KEY] = "false"
      assert_no_difference "User.count" do
        post "/api/v1/users", params: signup_params, as: :json
      end
      assert_response :not_found
    end
  end

  test "the helper restores the flag after use (no leak between tests)" do
    before_present = ENV.key?(PublicSignupFlag::KEY)
    before_value = ENV[PublicSignupFlag::KEY]

    with_public_signup("true") { assert_equal "true", ENV[PublicSignupFlag::KEY] }
    assert_raises(RuntimeError) { with_public_signup("true") { raise "boom" } }

    assert_equal before_present, ENV.key?(PublicSignupFlag::KEY)
    assert_equal before_value, ENV[PublicSignupFlag::KEY]
  end

  # ---- CA2: disabled has no effect ----

  test "CA2: disabled, an anonymous POST answers 404 and creates no user, organization, membership or token (organization_id, organization_name, none, no params)" do
    existing_org = Organization.create!(name: "Org Alvo #{SecureRandom.hex(3)}")
    bodies = [
      signup_params(organization_id: existing_org.id),
      signup_params(organization_id: 999_999_999),
      signup_params(organization_name: "Nova Org #{SecureRandom.hex(3)}"),
      signup_params,
      {},
      { user: {} }
    ]

    with_public_signup(nil) do
      bodies.each do |body|
        before = counts
        post "/api/v1/users", params: body, as: :json

        assert_not_found_envelope
        assert_equal before, counts, "body=#{body.inspect}"
      end
    end
    assert_equal 0, existing_org.memberships.count
  end

  test "CA2: disabled with an explicit false, nothing is created either" do
    with_public_signup("false") do
      assert_no_difference [ "User.count", "Organization.count", "Membership.count" ] do
        post "/api/v1/users", params: signup_params(organization_name: "Org Falsa"), as: :json
      end
      assert_not_found_envelope
    end
  end

  # ---- CA3: other anonymous actions ----

  test "CA3: disabled, GET sign_up and GET cancel also answer 404 in the API envelope" do
    with_public_signup(nil) do
      get "/api/v1/users/sign_up"
      assert_not_found_envelope

      get "/api/v1/users/cancel"
      assert_not_found_envelope
    end
  end

  test "CA3: disabled, POST /users by an already authenticated user also answers 404 and creates nothing" do
    org = Organization.create!(name: "Org Auth #{SecureRandom.hex(3)}")
    user = User.create!(email: "logged.#{SecureRandom.hex(3)}@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: org, role: "editor")
    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: org.id } }, as: :json
    auth = { "Authorization" => response.headers["Authorization"] }

    with_public_signup(nil) do
      assert_no_difference [ "User.count", "Organization.count", "Membership.count" ] do
        post "/api/v1/users", params: signup_params(organization_name: "Outra"), headers: auth, as: :json
      end
      assert_response :not_found
      assert_equal "NOT_FOUND", response.parsed_body["code"]
    end
  end

  # ---- CA4: enabled keeps the legitimate flow ----

  test "CA4: enabled, organization_name creates the user, a new organization and an admin membership in that new organization" do
    with_public_signup("true") do
      assert_difference [ "User.count", "Organization.count", "Membership.count" ], 1 do
        post "/api/v1/users", params: signup_params(email: "owner@example.com", organization_name: "Rede Nova"), as: :json
      end
    end

    assert_response :created
    organization = response.parsed_body.dig("data", "organization")
    assert_equal "Rede Nova", organization["name"]
    assert_equal "admin", organization["role"]
    created = Organization.find(organization["id"])
    assert_equal "admin", created.memberships.find_by!(user: User.find_by!(email: "owner@example.com")).role
  end

  test "CA4: enabled, no organization creates only the user (no membership), as today" do
    with_public_signup("true") do
      assert_difference "User.count", 1 do
        assert_no_difference [ "Organization.count", "Membership.count" ] do
          post "/api/v1/users", params: signup_params, as: :json
        end
      end
    end

    assert_response :created
    assert_nil response.parsed_body.dig("data", "organization")
  end

  # ---- CA5: organization_id never attaches ----

  test "CA5: enabled, any present organization_id (existing or not) answers 422 VALIDATION_ERROR, creates nothing and emits no token" do
    existing_org = Organization.create!(name: "Org Existente #{SecureRandom.hex(3)}")

    with_public_signup("true") do
      [ existing_org.id, 999_999_999, existing_org.id.to_s ].each do |org_id|
        before = counts
        post "/api/v1/users", params: signup_params(organization_id: org_id), as: :json

        assert_response :unprocessable_entity, "organization_id=#{org_id}"
        body = response.parsed_body
        assert_equal "VALIDATION_ERROR", body["code"]
        assert_match(/organization_id/, [ body["message"], body["details"] ].flatten.join(" "))
        assert_nil response.headers["Authorization"]
        assert_equal before, counts
      end
    end
    assert_equal 0, existing_org.memberships.count
  end

  test "CA5: enabled, organization_id together with organization_name is also refused and creates no organization" do
    existing_org = Organization.create!(name: "Org Existente 2 #{SecureRandom.hex(3)}")

    with_public_signup("true") do
      assert_no_difference [ "User.count", "Organization.count", "Membership.count" ] do
        post "/api/v1/users", params: signup_params(organization_id: existing_org.id, organization_name: "Misturada"), as: :json
      end
    end
    assert_response :unprocessable_entity
  end

  # ---- CA6: other Devise actions unchanged (characterization, identical with the flag on and off) ----

  test "CA6: edit, update (PATCH/PUT) and destroy keep requiring authentication, whatever the flag (characterization)" do
    [ nil, "true" ].each do |flag|
      with_public_signup(flag) do
        get "/api/v1/users/edit"
        assert_response :unauthorized, "GET edit flag=#{flag.inspect}"

        patch "/api/v1/users", params: { user: { email: "other@example.com" } }, as: :json
        assert_response :unauthorized, "PATCH flag=#{flag.inspect}"

        put "/api/v1/users", params: { user: { email: "other@example.com" } }, as: :json
        assert_response :unauthorized, "PUT flag=#{flag.inspect}"

        delete "/api/v1/users", as: :json
        assert_response :unauthorized, "DELETE flag=#{flag.inspect}"
      end
    end
  end

  # ---- CA7: login and other flows unaffected (characterization) ----

  test "CA7: sign_in and logout keep working with the flag off (characterization)" do
    user = User.create!(email: "login.#{SecureRandom.hex(3)}@example.com", password: "Password!123", password_confirmation: "Password!123")

    with_public_signup(nil) do
      post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123" } }, as: :json
      assert_response :ok
      auth = response.headers["Authorization"]
      assert auth.present?

      delete "/api/v1/logout", headers: { "Authorization" => auth }, as: :json
      assert_includes [ 200, 204 ], response.status
    end
  end

  test "CA7: sign_in with wrong credentials still answers the standard 401 envelope with the flag off (characterization)" do
    with_public_signup(nil) do
      post "/api/v1/users/sign_in", params: { user: { email: "missing@example.com", password: "wrong" } }, as: :json
      assert_response :unauthorized
      assert_equal "INVALID_CREDENTIALS", response.parsed_body["code"]
    end
  end

  test "CA7: a global admin still lists users through admin/users with the flag off (characterization)" do
    org = Organization.create!(name: "Org Admin #{SecureRandom.hex(3)}")
    admin = User.create!(email: "root.#{SecureRandom.hex(3)}@example.com", password: "Password!123", password_confirmation: "Password!123", admin: true)
    Membership.create!(user: admin, organization: org, role: "viewer")

    with_public_signup(nil) do
      post "/api/v1/users/sign_in", params: { user: { email: admin.email, password: "Password!123", organization_id: org.id } }, as: :json
      get "/api/v1/admin/users", headers: { "Authorization" => response.headers["Authorization"] }
      assert_response :ok
      assert_includes response.parsed_body["data"].map { |u| u["email"] }, admin.email
    end
  end

  test "CA7: Bootstrap::EnsureMasterUser still creates the global master user without any flag (characterization)" do
    with_public_signup(nil) do
      result = nil
      assert_difference "User.count", 1 do
        result = Bootstrap::EnsureMasterUser.new(email: "master.#{SecureRandom.hex(3)}@example.com", password: "Password!123").call
      end
      assert result.created
      assert User.find_by!(email: result.email).admin?
    end
  end
end
