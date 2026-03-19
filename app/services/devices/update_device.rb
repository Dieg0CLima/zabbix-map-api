class Devices::UpdateDevice
  def initialize(device:, params:, actor: nil)
    @device = device
    @params = params
    @actor = actor
  end

  def call
    attrs = @params.deep_dup
    attrs[:metadata] = (@device.metadata || {}).merge(attrs[:metadata] || {}).merge("updated_by_id" => @actor&.id)
    @device.update!(attrs)
    @device
  end
end
