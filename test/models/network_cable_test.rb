require "test_helper"

class NetworkCableTest < ActiveSupport::TestCase
  test "resolves source_pop_id and optional target_pop_id from external ids" do
    organization = Organization.create!(name: "Org Cable")
    network_map = organization.network_maps.create!(name: "Mapa Cable", source_type: "manual")

    source_pop = network_map.map_pops.create!(name: "POP Origem", external_id: "pop-source", lat: -23.1, lng: -46.1, color: "#7c3aed")

    cable = network_map.network_cables.create!(
      source_pop_id: source_pop.external_id,
      target_pop_id: nil,
      cable_type: "manual",
      status: "planned",
      metadata: { fiber_count: 12 }
    )

    assert_equal source_pop.id, cable.source_pop_id
    assert_nil cable.target_pop_id
  end

  test "resolves source and target nodes from attached sites" do
    organization = Organization.create!(name: "Org Cable Site")
    network_map = organization.network_maps.create!(name: "Mapa Cable Site", source_type: "manual")
    source_site = organization.sites.create!(name: "Site A", slug: "site-a")
    target_site = organization.sites.create!(name: "Site B", slug: "site-b")

    source_node = network_map.map_nodes.create!(
      external_id: "node-site-a",
      label: "Site A",
      node_kind: "generic",
      x: -23.1,
      y: -46.1,
      lat: -23.1,
      lng: -46.1,
      mappable: source_site
    )
    target_node = network_map.map_nodes.create!(
      external_id: "node-site-b",
      label: "Site B",
      node_kind: "generic",
      x: -23.2,
      y: -46.2,
      lat: -23.2,
      lng: -46.2,
      mappable: target_site
    )

    cable = network_map.network_cables.create!(
      source_site_id: source_site.id,
      target_site_id: target_site.id,
      status: "planned",
      cable_type: "manual"
    )

    assert_equal source_node.id, cable.source_node_id
    assert_equal target_node.id, cable.target_node_id
    assert_equal source_site.id, cable.source_site_id
    assert_equal target_site.id, cable.target_site_id
  end

  test "validates source_site_id when site marker is missing from map" do
    organization = Organization.create!(name: "Org Cable Site Missing")
    network_map = organization.network_maps.create!(name: "Mapa Cable Missing", source_type: "manual")
    unattached_site = organization.sites.create!(name: "Site Solto", slug: "site-solto")

    cable = network_map.network_cables.new(source_site_id: unattached_site.id, status: "planned", cable_type: "manual")

    assert_not cable.valid?
    assert_includes cable.errors[:source_site_id], "must reference a Site marker attached to this map"
  end
end
