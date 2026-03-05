class Api::V1::ZabbixConnectionsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_zabbix_connection, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    connections = scoped_zabbix_connections.order(:id)

    render json: { data: connections.map { |connection| connection_payload(connection) } }, status: :ok
  end

  def show
    render json: { data: connection_payload(@zabbix_connection) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    connection = ZabbixConnections::Create.new(
      organization: current_organization,
      payload: zabbix_connection_params
    ).call

    render json: { data: connection_payload(connection) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    ZabbixConnections::Update.new(
      connection: @zabbix_connection,
      payload: zabbix_connection_params
    ).call

    render json: { data: connection_payload(@zabbix_connection) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    ZabbixConnections::Destroy.new(connection: @zabbix_connection).call
    head :no_content
  end

  private

  def set_zabbix_connection
    @zabbix_connection = scoped_zabbix_connections.find(params[:id])
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

  def connection_payload(connection)
    ZabbixConnections::PayloadBuilder.new(connection:).call
  end
end
