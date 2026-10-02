require "test_helper"

# REQ-004: effective values today (load_defaults 8.0) of the two JSON-escaping switches. They must stay
# true after `load_defaults 8.1` + explicit pins (zero behavior change).
class JsonConfigCharacterizationTest < ActiveSupport::TestCase
  test "escape_js_separators_in_json is true" do
    assert_equal true, ActiveSupport.escape_js_separators_in_json
  end

  test "ActionController::Base.escape_json_responses is true" do
    assert_equal true, ActionController::Base.escape_json_responses
  end

  test "API base controller inherits escape_json_responses == true" do
    assert_equal true, Api::V1::BaseController.escape_json_responses
  end
end
