require "test_helper"

class Auth::Ldap::ConfigTest < ActiveSupport::TestCase
  test "normalizes enabled flags and servers" do
    config = Auth::Ldap::Config.new(
      {
        enabled: "true",
        allow_sign_up: "1",
        fallback_to_database_auth: "false",
        servers: [
          {
            host: "ad.local",
            port: "389",
            encryption: "start_tls",
            search_base_dns: [ "DC=example,DC=local" ]
          }
        ]
      }
    )

    assert config.enabled?
    assert config.allow_sign_up?
    assert_not config.fallback_to_database_auth?
    assert_equal "ad.local", config.servers.first[:host]
    assert_equal({ method: :start_tls }, config.servers.first[:encryption])
  end
end
