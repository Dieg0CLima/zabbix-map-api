require "test_helper"

class Api::V1::LdapSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ldap.admin@example.com", password: "Password!123", password_confirmation: "Password!123")
    @organization = Organization.create!(name: "LDAP Org")
    Membership.create!(user: @user, organization: @organization, role: "admin")

    post "/api/v1/users/sign_in", params: {
      user: {
        email: @user.email,
        password: "Password!123",
        organization_id: @organization.id
      }
    }, as: :json

    @auth_headers = { "Authorization" => response.headers["Authorization"] }
  end

  test "show returns ldap settings payload" do
    get "/api/v1/ldap_settings", headers: @auth_headers, as: :json

    assert_response :ok
    body = response.parsed_body.fetch("data")
    assert body.key?("enabled")
    assert body.key?("host")
  end

  test "update persists ldap settings" do
    put "/api/v1/ldap_settings", params: {
      ldap_setting: {
        enabled: true,
        allow_sign_up: true,
        fallback_to_database_auth: false,
        host: "ad.example.local",
        port: 389,
        encryption: "start_tls",
        bind_dn: "CN=svc,OU=Users,DC=example,DC=local",
        bind_password: "super-secret",
        search_base_dn: "DC=example,DC=local",
        search_filter: "(sAMAccountName=%{login})",
        attr_username: "sAMAccountName",
        attr_email: "mail",
        attr_name: "displayName"
      }
    }, headers: @auth_headers, as: :json

    assert_response :ok

    setting = LdapSetting.first
    assert_equal "ad.example.local", setting.host
    assert_equal true, setting.enabled
    assert_equal false, setting.fallback_to_database_auth
  end

  test "test_connection returns user mapping and groups even when user authentication fails" do
    diagnostic_result = Struct.new(
      :success?, :auth_success?, :stage, :code, :detail, :hint, :user_information, :ldap_attributes, :ldap_groups, :search_attempts, :resolved_dn_candidates
    ).new(
      false,
      false,
      "user_auth",
      "invalid_credentials",
      "Senha inválida para o usuário de teste.",
      "Dados LDAP foram coletados mesmo com falha de senha.",
      {
        "dn" => "CN=Usuario Teste,OU=Users,DC=mcdtelecom,DC=srv",
        "username" => "usuario.teste",
        "email" => "usuario.teste@mcdtelecom.srv",
        "name" => "Usuário Teste"
      },
      {
        "sAMAccountName" => [ "usuario.teste" ],
        "mail" => [ "usuario.teste@mcdtelecom.srv" ]
      },
      [
        "CN=NOC,OU=Groups,DC=mcdtelecom,DC=srv",
        "CN=Monitoring,OU=Groups,DC=mcdtelecom,DC=srv"
      ],
      [ { "base_dn" => "dc=mcdtelecom,dc=srv", "filter" => "(sAMAccountName=usuario.teste)", "count" => 0 } ],
      [ "cn=usuario.teste,dc=mcdtelecom,dc=srv" ]
    )
    diagnostic = Struct.new(:result) { def call(**_kwargs) = result }.new(diagnostic_result)

    diagnostic_factory = ->(**_kwargs) { diagnostic }
    Auth::Ldap::ConnectionDiagnostic.stub :new, diagnostic_factory do
      post "/api/v1/ldap_settings/test_connection", params: {
        ldap_setting: {
          host: "10.1.32.20",
          port: 389,
          encryption: "start_tls",
          bind_dn: "srv-app@mcdtelecom.srv",
          bind_password: "secret",
          search_base_dn: "dc=mcdtelecom,dc=srv",
          search_filter: "(sAMAccountName=%{login})",
          attr_username: "sAMAccountName",
          attr_email: "mail",
          attr_name: "displayName"
        },
        login: "usuario.teste",
        password: "senha.teste"
      }, headers: @auth_headers, as: :json
    end

    assert_response :ok
    payload = response.parsed_body.fetch("data")
    assert_equal false, payload["success"]
    assert_equal false, payload["auth_success"]
    assert_equal "user_auth", payload["stage"]
    assert_equal "invalid_credentials", payload["code"]
    assert_equal "usuario.teste@mcdtelecom.srv", payload.dig("user_information", "email")
    assert_equal 2, payload["ldap_groups"].size
    assert payload["search_attempts"].is_a?(Array)
    assert payload["resolved_dn_candidates"].is_a?(Array)
  end
end
