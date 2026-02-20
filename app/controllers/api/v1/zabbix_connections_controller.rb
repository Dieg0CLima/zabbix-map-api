# app/controllers/api/v1/zabbix_connections_controller.rb
class Api::V1::ZabbixConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    connections =
      if admin_without_organization_context?
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

    connection = current_organization.zabbix_connections.new(filtered_zabbix_connection_params_for_write)

    if connection.save
      render json: { data: connection_payload(connection) }, status: :created
    else
      render json: { errors: connection.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @zabbix_connection.update(filtered_zabbix_connection_params_for_write)
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
    connections_scope =
      if admin_without_organization_context?
        ZabbixConnection
      else
        current_organization.zabbix_connections
      end

    @zabbix_connection = connections_scope.find(params[:id])
  end

  # Strong params "base"
  def zabbix_connection_params
    params.require(:zabbix_connection).permit(
      :name,
      :organization_id,
      :status,
      :base_url,
      :api_token,      # in-place encrypted
      :default_connection,
      :connection_mode,
      :db_adapter,
      :db_host,
      :db_port,
      :db_name,
      :db_username,
      :db_password,    # in-place encrypted
      metadata: {}
    )
  end


  def filtered_zabbix_connection_params_for_write
    attrs = zabbix_connection_params.to_h

    if attrs.key?("db_password") && attrs["db_password"].to_s.strip.empty?
      attrs.delete("db_password")
    end

    if attrs.key?("api_token") && attrs["api_token"].to_s.strip.empty?
      attrs.delete("api_token")
    end

    attrs
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
      last_synced_at: connection.last_synced_at,
      secrets: {
        has_db_password: connection.attributes_before_type_cast["db_password"].present?,
        has_api_token: connection.attributes_before_type_cast["api_token"].present?
      }
    }
  end
end
