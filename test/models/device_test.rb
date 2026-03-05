require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  test "resolves site_id from site external_id" do
    organization = Organization.create!(name: "Org Device")
    site = organization.sites.create!(name: "Site A", external_id: "site-a", status: "active")

    device = organization.devices.create!(name: "OLT-01", site_id: site.external_id, device_type: "olt", status: "planned")

    assert_equal site.id, device.site_id
  end
end
