require "test_helper"

class NetworkProjects::CreateTest < ActiveSupport::TestCase
  test "creates project aliasing network map model" do
    organization = Organization.create!(name: "Org NP Create")

    project = NetworkProjects::Create.new(
      organization:,
      payload: { name: "Projeto", source_type: "manual" }
    ).call

    assert project.persisted?
    assert_equal organization.id, project.organization_id
  end
end
