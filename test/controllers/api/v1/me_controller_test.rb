require "test_helper"

class Api::V1::MeControllerTest < ActionDispatch::IntegrationTest
  test "me returns authenticated user identity without organization context" do
    user = User.create!(
      email: "me.identity@example.com",
      password: "Password!123",
      password_confirmation: "Password!123"
    )

    post "/api/v1/users/sign_in", params: {
      user: {
        email: user.email,
        password: "Password!123"
      }
    }, as: :json

    assert_response :ok
    auth_headers = { "Authorization" => response.headers["Authorization"] }

    get "/api/v1/me", headers: auth_headers, as: :json

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    assert_equal user.id, payload["id"]
    assert_equal user.email, payload["email"]
    assert_not payload.key?("org_id")
  end
end
