class Api::V1::ZabbixHostsController < ApplicationController
  include DomainErrorHandler
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection

  def index
    hosts = ZabbixHosts::Fetch.new(connection: @zabbix_connection, limit: params[:limit]).call

    render json: { data: hosts }, status: :ok
  rescue Zabbix::DatabaseHostsFetcher::UnsupportedAdapterError => e
    render_validation_error({ adapter: e.message }, message: "Unsupported adapter")
  rescue Zabbix::DatabaseHostsFetcher::Error => e
    render_service_unavailable(message: "Unable to fetch hosts from Zabbix database", details: e.message)
  end

  private

  def set_zabbix_connection
    @zabbix_connection = scoped_zabbix_connections.find(params[:zabbix_connection_id])
  end
end
