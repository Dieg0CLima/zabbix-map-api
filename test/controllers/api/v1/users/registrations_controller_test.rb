require "test_helper"
require_relative "../../../../support/public_signup_flag"

class Api::V1::Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include PublicSignupFlag

  # REQ-008: public sign up is disabled by default, so these tests turn the flag on explicitly (restored by the helper).
  test "sign up creates user and organization via service" do
    with_public_signup("true") do
      assert_difference [ "User.count", "Organization.count", "Membership.count" ], 1 do
        post "/api/v1/users", params: {
          user: {
            email: "service.test@example.com",
            password: "Password!123",
            password_confirmation: "Password!123",
            organization_name: "Service Org"
          }
        }, as: :json
      end

      assert_response :created

      payload = response.parsed_body.fetch("data")
      organization = payload.fetch("organization")

      assert_equal "service.test@example.com", payload["email"]
      assert_equal "Service Org", organization["name"]
      assert_equal "service-org", organization["slug"]
      assert_equal "admin", organization["role"]
    end
  end

  test "CA5: with the flag on, organization_id is refused with 422 and nobody is attached to the existing organization" do
    existing_org = Organization.create!(name: "Pre-Existing Org")

    with_public_signup("true") do
      assert_no_difference [ "User.count", "Membership.count", "Organization.count" ] do
        post "/api/v1/users", params: {
          user: {
            email: "joiner@example.com",
            password: "Password!123",
            password_confirmation: "Password!123",
            organization_id: existing_org.id
          }
        }, as: :json
      end
    end

    assert_response :unprocessable_entity
    body = response.parsed_body
    assert_equal "VALIDATION_ERROR", body["code"]
    assert_match(/organization_id/, [ body["message"], body["details"] ].flatten.join(" "))
    assert_nil response.headers["Authorization"]
    assert_equal 0, existing_org.memberships.count
  end

  test "sign up without organization" do
    with_public_signup("true") do
      assert_difference "User.count", 1 do
        assert_no_difference [ "Organization.count", "Membership.count" ] do
          post "/api/v1/users", params: {
            user: {
              email: "solo@example.com",
              password: "Password!123",
              password_confirmation: "Password!123"
            }
          }, as: :json
        end
      end

      assert_response :created

      payload = response.parsed_body.fetch("data")
      assert_nil payload["organization"]
    end
  end

  test "sign up with invalid params returns standardized error" do
    with_public_signup("true") do
      post "/api/v1/users", params: {
        user: {
          email: "",
          password: "short"
        }
      }, as: :json

      assert_response :unprocessable_entity

      body = response.parsed_body
      assert_equal "VALIDATION_ERROR", body["code"]
      assert_equal "Registration failed", body["message"]
      assert body["details"].is_a?(Array)
    end
  end
end
