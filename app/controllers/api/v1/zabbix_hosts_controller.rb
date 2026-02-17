class Api::V1::ZabbixHostsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection

  def index
    hosts = @zabbix_connection.zabbix_hosts.order(:id)

    render json: { data: hosts }, status: :ok
  end

  private

  def set_zabbix_connection
    connections_scope = if admin_without_organization_context?
      ZabbixConnection
    else
      current_organization.zabbix_connections
    end

    @zabbix_connection = connections_scope.find(params[:zabbix_connection_id])
  end
end
