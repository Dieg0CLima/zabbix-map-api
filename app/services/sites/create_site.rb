class Sites::CreateSite
  def initialize(organization:, params:, map_context: nil, actor: nil)
    @organization = organization
    @params = params
    @map_context = map_context || {}
    @actor = actor
  end

  def call
    ActiveRecord::Base.transaction do
      site = @organization.sites.create!(site_attributes)
      marker = attach_to_map(site) if add_to_map?
      [site, marker]
    end
  end

  private

  def site_attributes
    attrs = @params.deep_dup
    attrs[:metadata] = (attrs[:metadata] || {}).merge("created_by_id" => @actor&.id)
    attrs
  end

  def add_to_map?
    ActiveModel::Type::Boolean.new.cast(@map_context[:add_to_map]) && @map_context[:network_map_id].present?
  end

  def attach_to_map(site)
    network_map = @organization.network_maps.find(@map_context[:network_map_id])
    Sites::AttachSiteToMap.new(network_map:, site:, params: marker_params, actor: @actor).call
  end

  def marker_params
    position = @map_context[:position] || {}
    {
      x: position[:lng] || position[:x],
      y: position[:lat] || position[:y],
      lat: position[:lat] || position[:y],
      lng: position[:lng] || position[:x],
      label_override: @map_context[:label_override],
      color: @map_context[:color_override],
      icon: @map_context[:icon_override],
      metadata: (@map_context[:metadata] || {}).merge("created_by_id" => @actor&.id)
    }
  end
end
