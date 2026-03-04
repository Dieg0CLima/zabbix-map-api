class NetworkProjects::Create
  def initialize(organization:, payload:)
    @organization = organization
    @payload = payload
  end

  def call
    project = @organization.network_maps.new(@payload)
    project.save!
    project
  end
end
