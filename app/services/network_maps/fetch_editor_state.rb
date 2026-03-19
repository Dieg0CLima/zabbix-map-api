class NetworkMaps::FetchEditorState
  def initialize(network_map:, current_membership: nil)
    @network_map = network_map
    @current_membership = current_membership
  end

  def call
    Api::V1::EditorStateSerializer.new(
      map: @network_map,
      elements: renderable_elements,
      sites: sites,
      devices: devices,
      zabbix_summary: Monitoring::MapHealthFetcher.new(network_map: @network_map, scope: renderable_elements).call,
      capabilities: capabilities
    ).as_json
  end

  private

  def renderable_elements
    @renderable_elements ||= NetworkMaps::RenderableElementsQuery.new(network_map: @network_map).call
  end

  def sites
    @sites ||= @network_map.organization.sites.order(:name)
  end

  def devices
    @devices ||= @network_map.organization.devices.includes(:site).order(:name)
  end

  def capabilities
    {
      can_create_site: can_edit?,
      can_create_device: can_edit?,
      can_edit_map: can_edit?
    }
  end

  def can_edit?
    @current_membership&.role.in?(%w[admin editor])
  end
end
