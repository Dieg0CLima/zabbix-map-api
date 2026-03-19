require "test_helper"

class Api::V1::DeviceObservabilityControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Org Device Obs", slug: "org-device-obs-#{SecureRandom.hex(4)}")
    @user = User.create!(email: "obs.viewer@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: @user, organization: @organization, role: "viewer")
    @device = @organization.devices.create!(name: "RTR-OBS", role: "router", status: "active")

    post "/api/v1/users/sign_in", params: { user: { email: @user.email, password: "Password!123", organization_id: @organization.id } }, as: :json
    @auth_header = response.headers["Authorization"]
  end

  test "show returns normalized observability summary scoped to organization" do
    summary_payload = {
      status: "problem",
      events: { status: "problem", active_problems: 2, severity_breakdown: { high: 1 }, events: [] },
      interfaces: [{ name: "eth0", ip: "10.0.0.1", main: true, type: "snmp", traffic: { in_bps: 1, out_bps: 2 }, status: "up" }],
      metrics: { traffic: [], cpu: { usage: 72 }, memory: { usage: 65 } },
      last_updated_at: "2026-03-18T20:15:00Z",
      zabbix_unavailable: false
    }

    fetcher = Minitest::Mock.new
    fetcher.expect(:call, summary_payload)

    Zabbix::Observability::FetchDeviceSummary.stub(:new, fetcher) do
      get "/api/v1/devices/#{@device.id}/observability", params: { organization_id: @organization.id }, headers: auth_headers, as: :json
    end

    assert_response :ok
    assert_equal "problem", response.parsed_body.dig("data", "status")
    assert_equal 72, response.parsed_body.dig("data", "metrics", "cpu", "usage")
    fetcher.verify
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
