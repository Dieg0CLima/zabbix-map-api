require "test_helper"

class Zabbix::Observability::FetchDeviceSummaryTest < ActiveSupport::TestCase
  test "returns unknown and zabbix unavailable when service fails" do
    organization = Organization.create!(name: "Obs Org Summary")
    connection = organization.zabbix_connections.create!(name: "Primary", status: "active", connection_mode: "api", base_url: "https://zabbix.example", api_token: "token")
    device = organization.devices.create!(name: "FW-01", role: "firewall", status: "active")
    device.zabbix_links.create!(organization:, zabbix_connection: connection, resource_type: "host", external_id: "30303", name: "FW-01")

    failing_events = Class.new do
      def initialize(device:); end
      def call = raise(Zabbix::Client::TransportError, "timeout")
      def default_payload = { status: "unknown", active_problems: 0, severity_breakdown: {}, events: [] }
    end

    failing_metrics = Class.new do
      def initialize(device:); end
      def call = raise(Zabbix::Client::TransportError, "timeout")
      def default_payload = { traffic: [], cpu: { usage: nil }, memory: { usage: nil } }
    end

    service = Zabbix::Observability::FetchDeviceSummary.new(device:, events_service: failing_events, metrics_service: failing_metrics)
    payload = service.call

    assert_equal "unknown", payload[:status]
    assert_equal true, payload[:zabbix_unavailable]
    assert_equal [], payload[:interfaces]
  end

  test "uses cache to avoid repeated upstream calls" do
    organization = Organization.create!(name: "Obs Org Cache")
    connection = organization.zabbix_connections.create!(name: "Primary", status: "active", connection_mode: "api", base_url: "https://zabbix.example", api_token: "token")
    device = organization.devices.create!(name: "OLT-01", role: "olt", status: "active")
    device.zabbix_links.create!(organization:, zabbix_connection: connection, resource_type: "host", external_id: "40404", name: "OLT-01")

    store = ActiveSupport::Cache::MemoryStore.new
    cache = Zabbix::Observability::Cache.new(store:, ttl: 5.minutes)
    calls = { value: 0 }

    fake_events = Class.new do
      def initialize(device:); @calls = self.class.calls; end
      def self.calls=(calls); @calls = calls; end
      def self.calls; @calls; end
      def call
        @calls[:value] += 1
        { status: "ok", active_problems: 0, severity_breakdown: {}, events: [], zabbix_unavailable: false }
      end
    end
    fake_events.calls = calls

    fake_metrics = Class.new do
      def initialize(device:); @calls = self.class.calls; end
      def self.calls=(calls); @calls = calls; end
      def self.calls; @calls; end
      def call
        @calls[:value] += 1
        { traffic: [], cpu: { usage: 1 }, memory: { usage: 2 }, zabbix_unavailable: false }
      end
    end
    fake_metrics.calls = calls

    fake_interfaces = Class.new do
      def initialize(device:); @calls = self.class.calls; end
      def self.calls=(calls); @calls = calls; end
      def self.calls; @calls; end
      def call
        @calls[:value] += 1
        { data: [], zabbix_unavailable: false }
      end
    end
    fake_interfaces.calls = calls

    service = Zabbix::Observability::FetchDeviceSummary.new(device:, cache:, events_service: fake_events, metrics_service: fake_metrics, interfaces_service: fake_interfaces)
    2.times { service.call }

    assert_equal 3, calls[:value]
  end
end
