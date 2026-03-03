require "test_helper"

class NetworkCables::EventRecorderTest < ActiveSupport::TestCase
  test "records event with defaults" do
    organization = Organization.create!(name: "Org Event Recorder")
    network_map = organization.network_maps.create!(name: "Mapa Event Recorder", source_type: "manual")
    pop = network_map.map_pops.create!(name: "POP", external_id: "pop-1", lat: -23.1, lng: -46.1, color: "#000000")
    cable = network_map.network_cables.create!(source_pop: pop, status: "planned")

    NetworkCables::EventRecorder.new(network_map:, actor_email: "editor@example.com").record!(
      cable:,
      event_type: "updated"
    )

    event = cable.network_cable_events.last
    assert_equal "updated", event.event_type
    assert_equal({}, event.before_state)
    assert_equal({}, event.after_state)
  end
end
