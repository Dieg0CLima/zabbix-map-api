require "test_helper"

class NetworkCableItemTest < ActiveSupport::TestCase
  test "supports extended metric roles for operational cable monitoring" do
    assert_includes NetworkCableItem::METRIC_ROLES, "bandwidth_in"
    assert_includes NetworkCableItem::METRIC_ROLES, "bandwidth_out"
    assert_includes NetworkCableItem::METRIC_ROLES, "status"
    assert_includes NetworkCableItem::METRIC_ROLES, "error_in"
    assert_includes NetworkCableItem::METRIC_ROLES, "error_out"
    assert_includes NetworkCableItem::METRIC_ROLES, "crc_in"
    assert_includes NetworkCableItem::METRIC_ROLES, "crc_out"
  end
end
