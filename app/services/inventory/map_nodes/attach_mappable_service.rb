class Inventory::MapNodes::AttachMappableService
  def initialize(network_map:, mappable:, params:)
    @network_map = network_map
    @mappable = mappable
    @params = params
  end

  def call
    map_node = @network_map.map_nodes.new(default_params.merge(@params))
    map_node.mappable = @mappable
    map_node.save!
    map_node
  end

  private

  def default_params
    {
      label: @mappable.try(:name) || @mappable.class.name,
      label_override: @params[:label_override],
      node_kind: inferred_node_kind,
      x: @params[:x],
      y: @params[:y],
      lat: @params[:lat] || @params[:y],
      lng: @params[:lng] || @params[:x],
      icon: @params[:icon] || "pi-box",
      color: @params[:color] || "#2563eb",
      size: @params[:width] || 32,
      width: @params[:width] || 32,
      height: @params[:height] || 32,
      visible: @params.fetch(:visible, true),
      collapsed: @params.fetch(:collapsed, false),
      metadata: @params[:metadata] || {}
    }
  end

  def inferred_node_kind
    @mappable.is_a?(Site) ? "gateway" : (@mappable.try(:role) || "generic")
  end
end
