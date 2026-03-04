class Api::V1::ZabbixItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection

  def index
    items = ZabbixItems::Fetch.new(
      connection: @zabbix_connection,
      hostid: params[:hostid],
      zabbix_host_id: params[:zabbix_host_id],
      limit: params[:limit]
    ).call

    render json: { data: items }, status: :ok
  rescue Zabbix::DatabaseItemsFetcher::UnsupportedAdapterError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Zabbix::DatabaseItemsFetcher::Error => e
    render json: { error: "Unable to fetch items from Zabbix database", details: e.message }, status: :service_unavailable
  end

  private

  def set_zabbix_connection
    @zabbix_connection = zabbix_connections_scope.find(params[:zabbix_connection_id])
  end

  def zabbix_connections_scope
    admin_without_organization_context? ? ZabbixConnection : current_organization.zabbix_connections
  end

end
