require "test_helper"

class Devices::DropdownPayloadBuilderTest < ActiveSupport::TestCase
  test "builds dropdown payload for device" do
    organization = Organization.create!(name: "Org Devices Dropdown")
    site = organization.sites.create!(name: "Site One", slug: "site-one")
    device = organization.devices.create!(site: site, name: "Core BSB", hostname: "core-bsb-01", role: "switch", status: "active")

    payload = Devices::DropdownPayloadBuilder.new(device).call

    assert_equal device.id, payload[:value]
    assert_equal "Core BSB", payload[:label]
    assert_equal "core-bsb-01", payload[:code]
    assert_equal site.id, payload.dig(:meta, :site_id)
    assert_equal "switch", payload.dig(:meta, :role)
    assert_equal "active", payload.dig(:meta, :status)
  end
end
