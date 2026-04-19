require "test_helper"

class NetworkMapTest < ActiveSupport::TestCase
  test "accepts supported active_base_layer values" do
    organization = Organization.create!(name: "Org Base Layer")

    NetworkMap::BASE_LAYERS.each do |layer|
      map = organization.network_maps.new(name: "Mapa #{layer}", source_type: "manual", active_base_layer: layer)
      assert map.valid?, "expected #{layer} to be a valid active_base_layer"
    end
  end

  test "rejects unsupported active_base_layer values" do
    organization = Organization.create!(name: "Org Base Layer Invalid")
    map = organization.network_maps.new(name: "Mapa inválido", source_type: "manual", active_base_layer: "watercolor")

    assert_not map.valid?
    assert_includes map.errors[:active_base_layer], "is not included in the list"
  end
end
