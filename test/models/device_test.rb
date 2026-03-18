require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Org Test Device")
    @site = @organization.sites.create!(name: "Site SP")
  end

  test "generates external_id when not provided" do
    device = @organization.devices.create!(name: "Router Core")

    assert device.external_id.present?
    assert_match(/\Adevice-/, device.external_id)
  end

  test "requires name" do
    device = @organization.devices.new
    assert_not device.valid?
    assert_includes device.errors[:name], "can't be blank"
  end

  test "enforces external_id uniqueness within organization" do
    @organization.devices.create!(name: "Device A", external_id: "dev-001")

    duplicate = @organization.devices.new(name: "Device B", external_id: "dev-001")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "can belong to a site" do
    device = @organization.devices.create!(name: "Switch", site: @site)
    assert_equal @site.id, device.site_id
  end

  test "can exist without a site" do
    device = @organization.devices.new(name: "Router Standalone")
    assert device.valid?, device.errors.full_messages.to_s
  end

  test "validates status inclusion" do
    device = @organization.devices.new(name: "Device", status: "bad_status")
    assert_not device.valid?
    assert device.errors[:status].present?
  end

  test "has many map_elements as mappable" do
    device = @organization.devices.create!(name: "Device")
    assert_respond_to device, :map_elements
  end
end
