require "test_helper"

class SitesCreateSiteTest < ActiveSupport::TestCase
  test "creates site and marker in one transaction when add_to_map is true" do
    organization = Organization.create!(name: "Org Create Site", slug: "org-create-site")
    network_map = NetworkMap.create!(organization:, name: "Ops Map")

    site, marker = Sites::CreateSite.new(
      organization:,
      params: { name: "POP Centro", slug: "pop-centro" },
      map_context: { add_to_map: true, network_map_id: network_map.id, position: { lat: 1, lng: 2 } }
    ).call

    assert_equal site, marker.mappable
    assert_equal network_map, marker.network_map
  end
end
