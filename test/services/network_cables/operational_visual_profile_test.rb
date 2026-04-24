require "test_helper"

class NetworkCables::OperationalVisualProfileTest < ActiveSupport::TestCase
  test "prioritizes warning/critical colors for indicator and cable" do
    payload = NetworkCables::OperationalVisualProfile.new(
      cable_status: "active",
      zabbix_status: "up",
      operational_state: "traffic_high",
      traffic_level: "high",
      alert_level: "warning"
    ).call

    assert_equal "#d97706", payload[:cable_color]
    assert_equal "#d97706", payload[:indicator_color]
    assert_equal "warn", payload[:indicator_severity]
    assert_equal "Tráfego alto", payload[:state_label]
  end

  test "uses no-traffic color for no-traffic states" do
    payload = NetworkCables::OperationalVisualProfile.new(
      cable_status: "active",
      zabbix_status: "up",
      operational_state: "up_no_traffic",
      traffic_level: "none",
      alert_level: "ok"
    ).call

    assert_equal "#000000", payload[:cable_color]
    assert_equal "#000000", payload[:indicator_color]
    assert_equal "#000000", payload[:traffic_color]
  end

  test "falls back to cable status color when alert is unknown and zabbix status is unknown" do
    payload = NetworkCables::OperationalVisualProfile.new(
      cable_status: "disabled",
      zabbix_status: nil,
      operational_state: nil,
      traffic_level: nil,
      alert_level: nil
    ).call

    assert_equal "#dc2626", payload[:cable_color]
    assert_equal "#64748b", payload[:status_color]
    assert_equal "secondary", payload[:indicator_severity]
    assert_equal "Desconhecido", payload[:state_label]
  end
end
