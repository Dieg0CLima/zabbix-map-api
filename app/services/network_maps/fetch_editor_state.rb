class NetworkMaps::FetchEditorState
  def initialize(network_map:, current_membership: nil)
    @network_map = network_map
    @current_membership = current_membership
  end

  def call
    {
      map: Api::V1::NetworkMapSerializer.new(@network_map).as_json,
      elements: @network_map.map_nodes.includes(:mappable).order(:id).map { |node| Api::V1::MapElementSerializer.new(node).as_json },
      sites: @network_map.organization.sites.order(:name).map { |site| Api::V1::SiteSerializer.new(site).as_json },
      devices: @network_map.organization.devices.includes(:site).order(:name).map { |device| Api::V1::DeviceSerializer.new(device).as_json },
      zabbix_summary: Monitoring::MapHealthFetcher.new(network_map: @network_map).call,
      capabilities: {
        can_create_site: can_edit?,
        can_create_device: can_edit?,
        can_edit_map: can_edit?
      }
    }
  end

  private

  def can_edit?
    @current_membership&.role.in?(%w[admin editor])
  end
end
