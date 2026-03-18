class NetworkMaps::BulkUpdateElements
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
        node = @network_map.map_nodes.find(item[:id])
        service_class = node.mappable_type == "Site" ? Sites::UpdateSiteMarker : Devices::UpdateDeviceMarker
        updated = service_class.new(map_node: node, params: item.except(:id), actor: @actor).call
        successes << Api::V1::MapElementSerializer.new(updated).as_json
      rescue StandardError => e
        errors << { item:, detail: e.message }
      end
    end

    { successes:, errors: }
  end
end
