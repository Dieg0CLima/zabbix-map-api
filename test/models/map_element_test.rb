require "test_helper"

class MapElementTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Org Test Element")
    @network_map  = @organization.network_maps.create!(name: "Mapa", source_type: "manual")
    @site         = @organization.sites.create!(name: "Site SP")
    @device       = @organization.devices.create!(name: "Router Core")
  end

  test "generates external_id when not provided" do
    element = @network_map.map_elements.create!(
      mappable: @site, lat: -23.55, lng: -46.63
    )

    assert element.external_id.present?
    assert_match(/\Aelem-/, element.external_id)
  end

  test "requires lat and lng" do
    element = @network_map.map_elements.new(mappable: @site)
    assert_not element.valid?
    assert element.errors[:lat].present?
    assert element.errors[:lng].present?
  end

  test "enforces external_id uniqueness within map" do
    @network_map.map_elements.create!(
      mappable: @site, lat: -23.55, lng: -46.63, external_id: "elem-001"
    )

    duplicate = @network_map.map_elements.new(
      mappable: @device, lat: 0, lng: 0, external_id: "elem-001"
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:external_id].present?
  end

  test "prevents adding same entity twice to a map" do
    @network_map.map_elements.create!(mappable: @site, lat: -23.55, lng: -46.63)

    second = @network_map.map_elements.new(mappable: @site, lat: 0.0, lng: 0.0)
    assert_not second.valid?
    assert second.errors[:mappable].present?
  end

  test "allows same entity in different maps" do
    map2 = @organization.network_maps.create!(name: "Mapa 2", source_type: "manual")
    @network_map.map_elements.create!(mappable: @site, lat: -23.55, lng: -46.63)
    element2 = map2.map_elements.new(mappable: @site, lat: -23.55, lng: -46.63)

    assert element2.valid?, element2.errors.full_messages.to_s
  end

  test "validates mappable_type inclusion" do
    element = @network_map.map_elements.new(
      mappable_type: "InvalidType", mappable_id: 1, lat: 0, lng: 0
    )
    assert_not element.valid?
    assert element.errors[:mappable_type].present?
  end

  test "display_label returns label_override when present" do
    element = @network_map.map_elements.create!(
      mappable: @site, lat: -23.55, lng: -46.63, label_override: "Custom Label"
    )
    assert_equal "Custom Label", element.display_label
  end

  test "display_label falls back to entity name" do
    element = @network_map.map_elements.create!(
      mappable: @site, lat: -23.55, lng: -46.63
    )
    assert_equal @site.name, element.display_label
  end

  test "site? returns true for Site-typed element" do
    element = @network_map.map_elements.create!(mappable: @site, lat: 0, lng: 0)
    assert element.site?
    assert_not element.device?
  end

  test "device? returns true for Device-typed element" do
    element = @network_map.map_elements.create!(mappable: @device, lat: 0, lng: 0)
    assert element.device?
    assert_not element.site?
  end

  test "validates mappable belongs to same organization" do
    other_org  = Organization.create!(name: "Other Org")
    other_site = other_org.sites.create!(name: "Other Site")

    element = @network_map.map_elements.new(mappable: other_site, lat: 0, lng: 0)
    assert_not element.valid?
    assert element.errors[:mappable].present?
  end
end
