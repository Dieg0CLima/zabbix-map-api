class NetworkProjects::Destroy
  def initialize(project:)
    @project = project
  end

  def call
    @project.destroy!
  end
end
