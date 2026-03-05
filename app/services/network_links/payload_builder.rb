class NetworkLinks::PayloadBuilder
  def initialize(network_link:)
    @network_link = network_link
  end

  def call
    {
      id: @network_link.id,
      organization_id: @network_link.organization_id,
      external_id: @network_link.external_id,
      label: @network_link.label,
      source_device_id: @network_link.source_device&.external_id || @network_link.source_device_id,
      target_device_id: @network_link.target_device&.external_id || @network_link.target_device_id,
      source_site_id: @network_link.source_site&.external_id || @network_link.source_site_id,
      target_site_id: @network_link.target_site&.external_id || @network_link.target_site_id,
      link_type: @network_link.link_type,
      bandwidth_mbps: @network_link.bandwidth_mbps,
      status: @network_link.status,
      zabbix_item_ref: @network_link.zabbix_item_ref,
      metadata: @network_link.metadata,
      created_at: @network_link.created_at,
      updated_at: @network_link.updated_at
    }
  end
end
