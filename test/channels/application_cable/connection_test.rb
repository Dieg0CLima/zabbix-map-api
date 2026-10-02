require "test_helper"

# REQ-002 characterization of ApplicationCable::Connection (current behavior on Rails 8.0.x).
# JWTs are minted at runtime through the app's own Warden JWT encoder/secret; nothing is hardcoded.
class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection

  def create_user(label = "conn")
    User.create!(email: "#{label}.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123")
  end

  def token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  def app_secret
    Warden::JWTAuth.config.secret
  end

  def signed(payload, secret: app_secret, algorithm: "HS256")
    JWT.encode(payload, secret, algorithm)
  end

  test "CA9: valid HS256 token with an existing user's jti is accepted and identifies current_user" do
    user = create_user
    connect params: { token: token_for(user) }
    assert_equal user, connection.current_user
  end

  test "CA10: missing token is rejected" do
    assert_reject_connection { connect }
  end

  test "CA10: empty token is rejected" do
    assert_reject_connection { connect params: { token: "" } }
  end

  test "CA11: malformed token is rejected" do
    assert_reject_connection { connect params: { token: "not-a-jwt" } }
    assert_reject_connection { connect params: { token: "a.b.c" } }
  end

  test "CA11: token signed with another secret is rejected" do
    user = create_user
    token = signed({ "jti" => user.jti, "sub" => user.id.to_s, "exp" => 1.hour.from_now.to_i }, secret: "#{SecureRandom.hex(16)}-other")
    assert_reject_connection { connect params: { token: token } }
  end

  test "CA11: expired token is rejected" do
    user = create_user
    token = signed({ "jti" => user.jti, "sub" => user.id.to_s, "exp" => 1.hour.ago.to_i })
    assert_reject_connection { connect params: { token: token } }
  end

  test "CA11: token with algorithm HS512 is rejected" do
    user = create_user
    token = signed({ "jti" => user.jti, "sub" => user.id.to_s, "exp" => 1.hour.from_now.to_i }, algorithm: "HS512")
    assert_reject_connection { connect params: { token: token } }
  end

  test "CA11: unsigned token (alg none) is rejected" do
    user = create_user
    token = JWT.encode({ "jti" => user.jti, "sub" => user.id.to_s, "exp" => 1.hour.from_now.to_i }, nil, "none")
    assert_reject_connection { connect params: { token: token } }
  end

  test "CA12: valid token whose jti matches no user is rejected" do
    token = signed({ "jti" => SecureRandom.uuid, "sub" => "0", "exp" => 1.hour.from_now.to_i })
    assert_reject_connection { connect params: { token: token } }
  end

  test "CA12: token of a user whose jti was rotated afterwards is rejected" do
    user = create_user
    token = token_for(user)
    user.update_column(:jti, SecureRandom.uuid)
    assert_reject_connection { connect params: { token: token } }
  end

  test "CA12: token without jti claim is rejected" do
    token = signed({ "sub" => "1", "exp" => 1.hour.from_now.to_i })
    assert_reject_connection { connect params: { token: token } }
  end
end
