class NetworkProjects::Update
  def initialize(project:, payload:)
    @project = project
    @payload = payload
  end

  def call
    @project.update!(@payload)
    @project
  end
end
