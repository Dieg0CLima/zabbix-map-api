require "test_helper"

class Devices::MonitoringProfileSyncTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Org", slug: "test-org")
    @device = @organization.devices.create!(
      external_id: SecureRandom.uuid,
      name: "Edge Router",
      role: "router",
      status: "planned"
    )
    @connection = @organization.zabbix_connections.create!(
      name: "Primary Zabbix",
      status: "active",
      connection_mode: "api",
      base_url: "https://zabbix.example",
      api_token: SecureRandom.hex(16)
    )
  end

  test "creates monitoring profile when host link exists" do
    create_host_link

    profile = Devices::MonitoringProfileSync.new(device: @device).call

    assert profile.persisted?
    assert_equal @connection, profile.zabbix_connection
    assert_equal "host-42", profile.zabbix_hostid
    assert_equal "Host 42", profile.host_label
    assert profile.linked?
  end

  test "destroys profile when host link removed" do
    create_host_link
    Devices::MonitoringProfileSync.new(device: @device).call

    @device.zabbix_links.destroy_all

    profile = Devices::MonitoringProfileSync.new(device: @device).call

    assert_nil profile
    assert_nil @device.monitoring_profile
  end

  private

  def create_host_link
    ZabbixLink.create!(
      organization: @organization,
      zabbix_connection: @connection,
      linkable: @device,
      resource_type: "host",
      external_id: "host-42",
      name: "Host 42",
      metadata: { hostid: "host-42" }
    )
  end
end
