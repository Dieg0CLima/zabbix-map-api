class NetworkMaps::BulkAttachDevices
  def initialize(network_map:, items:, actor: nil)
    @network_map = network_map
    @items = items
    @actor = actor
  end

  def call
    successes = []
    errors = []
    ActiveRecord::Base.transaction do
      @items.each do |item|
        device = @network_map.organization.devices.find(item[:device_id])
        marker = Devices::AttachDeviceToMap.new(network_map: @network_map, device:, params: marker_params(item), actor: @actor).call
        successes << Api::V1::MapElementSerializer.new(marker).as_json
      rescue StandardError => e
        errors << { item:, detail: e.message }
      end
    end
    { successes:, errors: }
  end

  private

  def marker_params(item)
    position = item[:position] || {}
    {
      x: position[:lng] || position[:x], y: position[:lat] || position[:y], lat: position[:lat] || position[:y], lng: position[:lng] || position[:x],
      label_override: item[:label_override], color: item[:color_override], icon: item[:icon_override], metadata: item[:metadata] || {}
    }
  end
end
