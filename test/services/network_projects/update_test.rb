require "test_helper"

class NetworkProjects::UpdateTest < ActiveSupport::TestCase
  test "updates project" do
    organization = Organization.create!(name: "Org NP Update")
    project = organization.network_maps.create!(name: "Projeto", source_type: "manual")

    updated = NetworkProjects::Update.new(project:, payload: { active_base_layer: "dark" }).call

    assert_equal "dark", updated.active_base_layer
  end
end
