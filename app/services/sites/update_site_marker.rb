class Sites::UpdateSiteMarker
  def initialize(map_node:, params:, actor: nil)
    @map_node = map_node
    @params = params
    @actor = actor
  end

  def call
    metadata = (@map_node.metadata || {}).merge(@params[:metadata] || {}).merge("updated_by_id" => @actor&.id)
    Inventory::MapNodes::UpdateLayoutService.new(
      map_node: @map_node,
      params: @params.merge(metadata:)
    ).call
  end
end
