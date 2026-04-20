require "test_helper"

class NetworkMaps::RecentEventsPayloadBuilderTest < ActiveSupport::TestCase
  test "builds events payload from network_map cable events association" do
    organization = Organization.create!(name: "Org Events #{SecureRandom.hex(3)}")
    network_map = organization.network_maps.create!(name: "Map Events", source_type: "manual")
    source_pop = network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.5, lng: -46.6)
    target_pop = network_map.map_pops.create!(name: "POP B", external_id: "pop-b", lat: -23.51, lng: -46.61)
    cable = network_map.network_cables.create!(
      external_id: "cable-events",
      source_pop: source_pop,
      target_pop: target_pop,
      cable_type: "fiber",
      status: "active"
    )

    event = network_map.network_cable_events.create!(
      network_cable: cable,
      event_type: "created",
      occurred_at: Time.current,
      actor: "test",
      notes: "created by test"
    )

    payload = NetworkMaps::RecentEventsPayloadBuilder.new(network_map: network_map).call

    assert_equal network_map.id, payload[:network_map_id]
    assert_equal 1, payload[:cable_events].size
    assert_equal event.id, payload[:cable_events].first[:id]
    assert_equal cable.external_id, payload[:cable_events].first[:cable_id]
  end
end
