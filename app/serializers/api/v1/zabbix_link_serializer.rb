class Api::V1::ZabbixLinkSerializer
  def initialize(zabbix_link)
    @zabbix_link = zabbix_link
  end

  def as_json(*)
    {
      id: @zabbix_link.id,
      organization_id: @zabbix_link.organization_id,
      zabbix_connection_id: @zabbix_link.zabbix_connection_id,
      linkable_type: @zabbix_link.linkable_type,
      linkable_id: @zabbix_link.linkable_id,
      resource_type: @zabbix_link.resource_type,
      external_id: @zabbix_link.external_id,
      external_key: @zabbix_link.external_key,
      name: @zabbix_link.name,
      metadata: @zabbix_link.metadata,
      created_at: @zabbix_link.created_at,
      updated_at: @zabbix_link.updated_at
    }
  end
end
