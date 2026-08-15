class Api::V1::ZabbixItemsController < ApplicationController
  include DomainErrorHandler
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection

  def index
    result = ZabbixItems::SummaryFetcher.new(
      connection: @zabbix_connection,
      hostid: params[:hostid],
      zabbix_host_id: params[:zabbix_host_id],
      limit: params[:limit]
    ).call

    render json: { data: result.items, meta: result.meta }, status: :ok
  rescue Zabbix::DatabaseItemsFetcher::UnsupportedAdapterError => e
    render_validation_error({ adapter: e.message }, message: "Unsupported adapter")
  rescue Zabbix::DatabaseItemsFetcher::Error => e
    render_service_unavailable(message: "Unable to fetch items from Zabbix database", details: e.message)
  end

  def history
    itemids = Array(params[:itemid] || params[:itemids])
    result = ZabbixItems::SelectedHistoryFetcher.new(
      connection: @zabbix_connection,
      itemids: itemids
    ).call

    render json: { data: result.items, meta: result.meta }, status: :ok
  rescue Zabbix::DatabaseConnection::UnsupportedAdapterError => e
    render_validation_error({ adapter: e.message }, message: "Unsupported adapter")
  rescue Zabbix::DatabaseConnection::Error => e
    render_service_unavailable(message: "Unable to fetch metric values", details: e.message)
  end

  def dropdown
    result = ZabbixItems::DropdownFetcher.new(
      connection: @zabbix_connection,
      zabbix_host_id: params[:zabbix_host_id]
    ).call

    render json: { data: result.items, meta: result.meta }, status: :ok
  end

  private

  def set_zabbix_connection
    @zabbix_connection = scoped_zabbix_connections.find(params[:zabbix_connection_id])
  end
end
