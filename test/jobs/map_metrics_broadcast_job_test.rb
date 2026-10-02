require "test_helper"

# REQ-002 characterization of MapMetricsBroadcastJob (current behavior on Rails 8.0.x), using the
# `test` cable adapter and the ActiveJob test adapter only. Maps have no zabbix_connection, so no
# Zabbix access happens. Limit: solid_cable (production adapter) is not exercised.
class MapMetricsBroadcastJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  def create_map(label)
    org = Organization.create!(name: "Org #{label} #{SecureRandom.hex(3)}")
    org.network_maps.create!(name: "Map #{label} #{SecureRandom.hex(3)}")
  end

  test "CA21: perform_now broadcasts exactly once to the map stream with type broadcast and the three payloads" do
    map = create_map("a21")
    stream = MapChannel.broadcasting_for(map)

    messages = capture_broadcasts(stream) { MapMetricsBroadcastJob.perform_now(map.id) }

    assert_equal 1, messages.size
    message = messages.first
    assert_equal "broadcast", message["type"]
    assert_equal %w[cable_metrics events metrics type], message.keys.sort
    assert_equal map.id, message["metrics"]["network_map_id"]
    assert_equal map.id, message["cable_metrics"]["network_map_id"]
    assert_equal map.id, message["events"]["network_map_id"]
  end

  test "CA22: non-existent map_id neither broadcasts nor raises (O6)" do
    missing_id = NetworkMap.maximum(:id).to_i + 1000
    stream = MapChannel.broadcasting_for(NetworkMap.new(id: missing_id))

    assert_no_broadcasts(stream) do
      assert_nothing_raised { MapMetricsBroadcastJob.perform_now(missing_id) }
    end
  end

  test "CA23: running for map A broadcasts nothing on map B's stream" do
    map_a = create_map("a23a")
    map_b = create_map("a23b")

    assert_broadcasts(MapChannel.broadcasting_for(map_a), 1) do
      assert_no_broadcasts(MapChannel.broadcasting_for(map_b)) do
        MapMetricsBroadcastJob.perform_now(map_a.id)
      end
    end
  end

  test "CA24: perform_later enqueues one job on the default queue with the map_id, without running it" do
    map = create_map("a24")

    assert_enqueued_with(job: MapMetricsBroadcastJob, args: [ map.id ], queue: "default") do
      MapMetricsBroadcastJob.perform_later(map.id)
    end
    assert_enqueued_jobs 1, only: MapMetricsBroadcastJob
    assert_no_broadcasts(MapChannel.broadcasting_for(map))
  end

  test "CA21/O3 (observation): the job's events payload carries actor and notes" do
    map = create_map("o3job")
    map.network_cable_events.create!(event_type: "created", occurred_at: 1.minute.ago, actor: "operator@example.com", notes: "synthetic note")

    messages = capture_broadcasts(MapChannel.broadcasting_for(map)) { MapMetricsBroadcastJob.perform_now(map.id) }

    event = messages.first["events"]["cable_events"].first
    assert_equal "operator@example.com", event["actor"]
    assert_equal "synthetic note", event["notes"]
  end
end
