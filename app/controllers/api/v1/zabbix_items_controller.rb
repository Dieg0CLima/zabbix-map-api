class Api::V1::ZabbixItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection

  def index
    items = @zabbix_connection.zabbix_items.order(:id)
    items = items.where(zabbix_host_id: params[:zabbix_host_id]) if params[:zabbix_host_id].present?

    render json: { data: items }, status: :ok
  end

  private

  def set_zabbix_connection
    @zabbix_connection = current_organization.zabbix_connections.find(params[:zabbix_connection_id])
  end
end
