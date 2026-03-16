class Api::V1::ZabbixItemsController < ApplicationController
  include DomainErrorHandler
  include OrganizationScoped

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
    render_validation_error({ adapter: e.message }, message: "Unsupported adapter")
  rescue Zabbix::DatabaseItemsFetcher::Error => e
    render_service_unavailable(message: "Unable to fetch items from Zabbix database", details: e.message)
  end

  def dropdown
    items = ZabbixItems::Fetch.new(
      connection: @zabbix_connection,
      hostid: params[:hostid],
      zabbix_host_id: params[:zabbix_host_id],
      limit: 200
    ).call

    data = items.map { |i| format_dropdown_item(i) }
    render json: { data: data }, status: :ok
  rescue Zabbix::DatabaseItemsFetcher::UnsupportedAdapterError => e
    render_validation_error({ adapter: e.message }, message: "Unsupported adapter")
  rescue Zabbix::DatabaseItemsFetcher::Error => e
    render_service_unavailable(message: "Unable to fetch items from Zabbix database", details: e.message)
  end

  private

  def set_zabbix_connection
    @zabbix_connection = scoped_zabbix_connections.find(params[:zabbix_connection_id])
  end

  def format_dropdown_item(item)
    if item.is_a?(Hash)
      {
        value: item[:itemid],
        label: "#{item[:name]} (#{item[:key_]})",
        itemid: item[:itemid],
        units: item[:units],
        value_type: item[:value_type]
      }
    else
      {
        value: item.id,
        label: "#{item.name} (#{item.key_})",
        itemid: item.itemid,
        units: item.units,
        value_type: item.value_type
      }
    end
  end
end
