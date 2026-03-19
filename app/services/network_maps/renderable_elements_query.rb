class NetworkMaps::RenderableElementsQuery
  RENDERABLE_MAPPABLE_TYPES = ["Site"].freeze

  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    @network_map.map_nodes
                .includes(:mappable)
                .where(mappable_type: RENDERABLE_MAPPABLE_TYPES)
                .order(:id)
                .select { |node| node.mappable.present? }
  end
end
