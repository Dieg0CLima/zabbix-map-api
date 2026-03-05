module OrganizationScoped
  extend ActiveSupport::Concern

  private

  def scoped_network_maps
    admin_without_organization_context? ? NetworkMap : current_organization.network_maps
  end

  def scoped_zabbix_connections
    admin_without_organization_context? ? ZabbixConnection : current_organization.zabbix_connections
  end
end
