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



  test "recent_data returns normalized host recent data payload" do
    recent_payload = {
      host: { id: "10101", label: "RTR-OBS" },
      items: [
        {
          id: "9001",
          host_id: "10101",
          host_label: "RTR-OBS",
          name: "Latência",
          key: "icmppingsec",
          last_check_at: "2026-03-19T10:00:00Z",
          last_check_ago_seconds: 13,
          last_value: "12.67ms",
          previous_value: "12.64ms",
          change: { raw: 0.03, display: "+0.03ms", direction: "up" },
          units: "ms",
          value_type: "float",
          status: "active",
          tags: [{ tag: "Application", value: "ICMP" }],
          applications: ["ICMP"],
          description: nil
        }
      ],
      total: 1,
      zabbix_unavailable: false
    }

    fetcher = Minitest::Mock.new
    fetcher.expect(:call, recent_payload)

    Zabbix::Observability::FetchRecentData.stub(:new, fetcher) do
      get "/api/v1/devices/#{@device.id}/observability/recent_data", params: { organization_id: @organization.id }, headers: auth_headers, as: :json
    end

    assert_response :ok
    assert_equal "Latência", response.parsed_body.dig("data", "items", 0, "name")
    fetcher.verify
  end

  private

  def auth_headers
    { "Authorization" => @auth_header }
  end
end
