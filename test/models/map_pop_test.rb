require "test_helper"

class MapPopTest < ActiveSupport::TestCase
  test "generates external_id when not provided" do
    organization = Organization.create!(name: "Org Pop")
    network_map = organization.network_maps.create!(name: "Mapa POP", source_type: "manual")

    pop = network_map.map_pops.create!(
      name: "POP Centro",
      lat: -23.55052,
      lng: -46.633308,
      color: "#7c3aed"
    )

    assert pop.external_id.present?
    assert_match(/\Apop-/, pop.external_id)
  end
end
