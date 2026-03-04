require "test_helper"

class NetworkCables::EventTypeInfererTest < ActiveSupport::TestCase
  test "returns status_changed when status differs" do
    event_type = NetworkCables::EventTypeInferer.infer(
      previous_state: { status: "planned", label: "A", color: "#000", metadata: {} },
      current_state: { status: "active", label: "A", color: "#000", metadata: {} },
      points_changed: false
    )

    assert_equal "status_changed", event_type
  end

  test "returns geometry_changed when points changed" do
    event_type = NetworkCables::EventTypeInferer.infer(
      previous_state: { status: "active", label: "A", color: "#000", metadata: {} },
      current_state: { status: "active", label: "A", color: "#000", metadata: {} },
      points_changed: true
    )

    assert_equal "geometry_changed", event_type
  end

  test "returns metadata_updated when metadata fields differ" do
    event_type = NetworkCables::EventTypeInferer.infer(
      previous_state: { status: "active", label: "A", color: "#000", metadata: { "a" => 1 } },
      current_state: { status: "active", label: "B", color: "#000", metadata: { "a" => 1 } },
      points_changed: false
    )

    assert_equal "metadata_updated", event_type
  end

  test "returns updated as fallback" do
    event_type = NetworkCables::EventTypeInferer.infer(
      previous_state: { status: "active", label: "A", color: "#000", metadata: { "a" => 1 } },
      current_state: { status: "active", label: "A", color: "#000", metadata: { "a" => 1 } },
      points_changed: false
    )

    assert_equal "updated", event_type
  end
end
