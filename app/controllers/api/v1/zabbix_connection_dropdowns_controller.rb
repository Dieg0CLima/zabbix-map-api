class Api::V1::ZabbixConnectionDropdownsController < Api::V1::BaseController
  before_action :set_connection

  def hosts
    render_data(data: Zabbix::HostFinder.new(connection: @connection, query: params[:query], limit: params[:limit] || 100).call)
  rescue StandardError => e
    render_errors(status: :service_unavailable, errors: [ { detail: e.message } ])
  end

  def items
    render_data(data: Zabbix::ItemFinder.new(connection: @connection, host_id: params[:host_id], limit: params[:limit] || 100).call)
  rescue StandardError => e
    render_errors(status: :service_unavailable, errors: [ { detail: e.message } ])
  end

  private

  def set_connection
    @connection = find_record(current_organization.zabbix_connections, params[:id])
  end
end
