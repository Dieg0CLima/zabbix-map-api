class Monitoring::MapBindings::UpdateService
  def initialize(binding:, params:)
    @binding = binding
    @params = params
  end

  def call
    @binding.update!(@params)
    @binding
  end
end
