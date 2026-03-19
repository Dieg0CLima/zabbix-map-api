class Devices::AttachDeviceToMap
  def initialize(network_map:, device:, params:, actor: nil)
    @network_map = network_map
    @device = device
    @params = params
    @actor = actor
  end

  def call
    existing = @network_map.map_nodes.find_by(mappable: @device)
    return existing if existing.present?

    Inventory::MapNodes::AttachMappableService.new(
      network_map: @network_map,
      mappable: @device,
      params: marker_params
    ).call
  end

  private

  def marker_params
    metadata = (@params[:metadata] || {}).merge("attached_by_id" => @actor&.id)
    @params.merge(metadata:)
  end
end
