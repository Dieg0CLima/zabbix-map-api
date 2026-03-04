# app/controllers/api/v1/zabbix_connections_controller.rb
class Api::V1::ZabbixConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    connections = zabbix_connections_scope.order(:id)

    render json: { data: connections.map { |connection| connection_payload(connection) } }, status: :ok
  end

  def show
    render json: { data: connection_payload(@zabbix_connection) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    connection = current_organization.zabbix_connections.create!(zabbix_connection_params)

    render json: { data: connection_payload(connection) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    @zabbix_connection.update!(zabbix_connection_params)

    render json: { data: connection_payload(@zabbix_connection) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    @zabbix_connection.destroy
    head :no_content
  end

  private

  def set_zabbix_connection
    @zabbix_connection = zabbix_connections_scope.find(params[:id])
  end

  def zabbix_connections_scope
    admin_without_organization_context? ? ZabbixConnection : current_organization.zabbix_connections
  end

  def zabbix_connection_params
    attrs = params.require(:zabbix_connection).permit(
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

    attrs.delete(:db_password) if attrs[:db_password].to_s.strip.empty?
    attrs.delete(:api_token) if attrs[:api_token].to_s.strip.empty?
    attrs
  end

  def assign_db_password(connection)
    return unless params.dig(:zabbix_connection, :db_password).present?

    connection.db_password = params.dig(:zabbix_connection, :db_password)
  end

  def connection_payload(connection)
    ZabbixConnections::PayloadBuilder.new(connection:).call
  end
end
