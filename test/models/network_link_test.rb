require "test_helper"

class NetworkLinkTest < ActiveSupport::TestCase
  test "resolves endpoint external ids" do
    organization = Organization.create!(name: "Org Link")
    source = organization.devices.create!(name: "SW-1", external_id: "device-sw1", device_type: "switch", status: "active")
    target = organization.devices.create!(name: "SW-2", external_id: "device-sw2", device_type: "switch", status: "active")

    link = organization.network_links.create!(
      external_id: "link-1",
      source_device_id: source.external_id,
      target_device_id: target.external_id,
      link_type: "fiber",
      status: "active"
    )

    assert_equal source.id, link.source_device_id
    assert_equal target.id, link.target_device_id
  end
end
