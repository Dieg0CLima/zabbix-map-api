class Api::V1::ZabbixHostsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection

  def index
    render json: { data: fetched_data }, status: :ok
  rescue Zabbix::DatabaseHostsFetcher::UnsupportedAdapterError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue Zabbix::DatabaseHostsFetcher::Error => e
    render json: { error: "Unable to fetch hosts from Zabbix database", details: e.message }, status: :service_unavailable
  end

  private

  def set_zabbix_connection
    @zabbix_connection = zabbix_connections_scope.find(params[:zabbix_connection_id])
  end

  def zabbix_connections_scope
    admin_without_organization_context? ? ZabbixConnection : current_organization.zabbix_connections
  end

  def fetched_data
    return @zabbix_connection.zabbix_hosts.order(:id) unless @zabbix_connection.db_enabled?

    Zabbix::DatabaseHostsFetcher.new(connection: @zabbix_connection, limit: params[:limit]).call
  end
end
