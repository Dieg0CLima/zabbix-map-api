class Monitoring::MapBindings::CreateService
  def initialize(map_node:, params:)
    @map_node = map_node
    @params = params
  end

  def call
    binding = @map_node.monitoring_bindings.new(@params)
    binding.save!
    binding
  end
end
