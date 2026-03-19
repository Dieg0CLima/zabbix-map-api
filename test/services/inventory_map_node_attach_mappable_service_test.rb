require "test_helper"

class InventoryMapNodeAttachMappableServiceTest < ActiveSupport::TestCase
  test "attaches existing device to map without duplicating inventory" do
    organization = Organization.create!(name: "Inventory Org", slug: "inventory-org")
    network_map = NetworkMap.create!(organization:, name: "Core Map")
    device = Device.create!(organization:, name: "SW-01", role: "switch", status: "active")

    map_node = Inventory::MapNodes::AttachMappableService.new(
      network_map:,
      mappable: device,
      params: { x: 10, y: 20 }
    ).call

    assert_equal device, map_node.mappable
    assert_equal 1, organization.devices.count
  end
end
