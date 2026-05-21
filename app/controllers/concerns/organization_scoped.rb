module OrganizationScoped
  extend ActiveSupport::Concern

  private

  def scoped_network_maps
    current_organization.network_maps
  end

  def scoped_zabbix_connections
    current_organization.zabbix_connections
  end
end
