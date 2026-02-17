class Api::V1::ZabbixConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    render json: { data: current_organization.zabbix_connections.order(:id).map { |connection| connection_payload(connection) } }, status: :ok
  end

  def show
    render json: { data: connection_payload(@zabbix_connection) }, status: :ok
  end

  def create
    connection = current_organization.zabbix_connections.new(zabbix_connection_params)

    if connection.save
      render json: { data: connection_payload(connection) }, status: :created
    else
      render json: { errors: connection.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @zabbix_connection.update(zabbix_connection_params)
      render json: { data: connection_payload(@zabbix_connection) }, status: :ok
    else
      render json: { errors: @zabbix_connection.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @zabbix_connection.destroy

    head :no_content
  end

  private

  def set_zabbix_connection
    @zabbix_connection = current_organization.zabbix_connections.find(params[:id])
  end

  def zabbix_connection_params
    params.require(:zabbix_connection).permit(
      :name,
      :status,
      :base_url,
      :api_token,
      :default_connection,
      :connection_mode,
      :db_adapter,
      :db_host,
      :db_port,
      :db_name,
      :db_username,
      :db_password,
      metadata: {}
    )
  end

  def connection_payload(connection)
    {
      id: connection.id,
      organization_id: connection.organization_id,
      name: connection.name,
      status: connection.status,
      base_url: connection.base_url,
      default_connection: connection.default_connection,
      connection_mode: connection.connection_mode,
      db_adapter: connection.db_adapter,
      db_host: connection.db_host,
      db_port: connection.db_port,
      db_name: connection.db_name,
      db_username: connection.db_username,
      metadata: connection.metadata,
      last_synced_at: connection.last_synced_at
    }
  end
end
