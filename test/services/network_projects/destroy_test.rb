require "test_helper"

class NetworkProjects::DestroyTest < ActiveSupport::TestCase
  test "destroys project" do
    organization = Organization.create!(name: "Org NP Destroy")
    project = organization.network_maps.create!(name: "Projeto", source_type: "manual")

    NetworkProjects::Destroy.new(project:).call

    assert_not NetworkMap.exists?(project.id)
  end
end
