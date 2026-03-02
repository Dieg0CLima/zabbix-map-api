require "test_helper"

class NetworkCables::EventTypeInfererTest < ActiveSupport::TestCase
  test "returns status_changed when status differs" do
    event_type = NetworkCables::EventTypeInferer.call(
      before_state: { status: "planned", points: [[0, 1, 2]], metadata: {} },
      after_state: { status: "active", points: [[0, 1, 2]], metadata: {} }
    )

    assert_equal "status_changed", event_type
  end

  test "returns geometry_changed when points differ" do
    event_type = NetworkCables::EventTypeInferer.call(
      before_state: { status: "active", points: [[0, 1, 2]], metadata: {} },
      after_state: { status: "active", points: [[0, 1, 3]], metadata: {} }
    )

    assert_equal "geometry_changed", event_type
  end

  test "returns metadata_updated when metadata differs" do
    event_type = NetworkCables::EventTypeInferer.call(
      before_state: { status: "active", points: [[0, 1, 2]], metadata: { "a" => 1 } },
      after_state: { status: "active", points: [[0, 1, 2]], metadata: { "a" => 2 } }
    )

    assert_equal "metadata_updated", event_type
  end
end
