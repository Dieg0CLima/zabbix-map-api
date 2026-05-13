require "test_helper"

class Api::V1::Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "sign up creates user and organization via service" do
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

  test "sign up joins existing organization" do
    existing_org = Organization.create!(name: "Pre-Existing Org")

    assert_difference [ "User.count", "Membership.count" ], 1 do
      assert_no_difference "Organization.count" do
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

    assert_response :created

    payload = response.parsed_body.fetch("data")
    organization = payload.fetch("organization")

    assert_equal existing_org.id, organization["id"]
    assert_equal "admin", organization["role"]
  end

  test "sign up without organization" do
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

  test "sign up with invalid params returns standardized error" do
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
