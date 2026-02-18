class Api::V1::ZabbixConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    connections = if admin_without_organization_context?
      ZabbixConnection.order(:id)
    else
      current_organization.zabbix_connections.order(:id)
    end

    render json: { data: connections.map { |connection| connection_payload(connection) } }, status: :ok
  end

  def show
    render json: { data: connection_payload(@zabbix_connection) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

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
    connections_scope = if admin_without_organization_context?
      ZabbixConnection
    else
      current_organization.zabbix_connections
    end

    @zabbix_connection = connections_scope.find(params[:id])
  end

  def zabbix_connection_params
    permitted = params.require(:zabbix_connection).permit(
      :name,
      :organization_id,
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

    permitted.delete(:db_password) if permitted[:db_password].blank?
    permitted
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
      has_db_password: connection.db_password.present?,
      metadata: connection.metadata,
      last_synced_at: connection.last_synced_at
    }
  end
end
