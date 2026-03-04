require "test_helper"

class NetworkMaps::UpdateTest < ActiveSupport::TestCase
  test "updates network map" do
    organization = Organization.create!(name: "Org NM Update")
    network_map = organization.network_maps.create!(name: "Mapa", source_type: "manual")

    updated = NetworkMaps::Update.new(network_map:, payload: { description: "Desc" }).call

    assert_equal "Desc", updated.description
  end
end
