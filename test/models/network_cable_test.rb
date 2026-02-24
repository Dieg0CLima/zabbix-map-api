require "test_helper"

class NetworkCableTest < ActiveSupport::TestCase
  test "resolves source_pop_id and target_pop_id from external ids" do
    organization = Organization.create!(name: "Org Cable")
    network_map = organization.network_maps.create!(name: "Mapa Cable", source_type: "manual")

    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-source", lat: -23.1, lng: -46.1, color: "#7c3aed")
    target_pop = network_map.map_pops.create!(name: "POP Destino", external_id: "pop-target", lat: -23.2, lng: -46.2, color: "#7c3aed")

    cable = network_map.network_cables.create!(
      source_pop_id: source_pop.external_id,
      target_pop_id: target_pop.external_id,
      cable_type: "logical",
      status: "unknown"
    )

    assert_equal source_pop.id, cable.source_pop_id
    assert_equal target_pop.id, cable.target_pop_id
  end
end
