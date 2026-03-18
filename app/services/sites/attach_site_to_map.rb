class Sites::AttachSiteToMap
  def initialize(network_map:, site:, params:, actor: nil)
    @network_map = network_map
    @site = site
    @params = params
    @actor = actor
  end

  def call
    existing = @network_map.map_nodes.find_by(mappable: @site)
    return existing if existing.present?

    Inventory::MapNodes::AttachMappableService.new(
      network_map: @network_map,
      mappable: @site,
      params: marker_params
    ).call
  end

  private

  def marker_params
    metadata = (@params[:metadata] || {}).merge("attached_by_id" => @actor&.id)
    @params.merge(metadata:)
  end
end
