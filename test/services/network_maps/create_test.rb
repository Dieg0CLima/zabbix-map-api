require "test_helper"

class NetworkMaps::CreateTest < ActiveSupport::TestCase
  test "creates network map for organization" do
    organization = Organization.create!(name: "Org NM Create")

    network_map = NetworkMaps::Create.new(
      organization:,
      payload: { name: "Mapa Novo", source_type: "manual" }
    ).call

    assert network_map.persisted?
    assert_equal organization.id, network_map.organization_id
  end
end
