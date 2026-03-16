class Api::V1::NetworkMapsController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    maps = scoped_network_maps.includes(:sites, map_nodes: :site, network_cables: :network_cable_points)

    render json: { data: maps.map { |map| network_map_payload(map) } }, status: :ok
  end

  def show
    render json: { data: network_map_payload(@network_map) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    network_map = NetworkMaps::Create.new(
      organization: current_organization,
      payload: permitted_network_map_payload.to_h
    ).call

    render json: { data: network_map_payload(network_map) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    NetworkMaps::Update.new(
      network_map: @network_map,
      payload: permitted_network_map_payload.to_h
    ).call

    render json: { data: network_map_payload(@network_map) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    NetworkMaps::Destroy.new(network_map: @network_map).call

    head :no_content
  end

  private

  def set_network_map
    @network_map = scoped_network_maps.find(params[:id])
  end

  def permitted_network_map_payload
    params.require(:network_map).permit(:name, :description, :source_type, :zabbix_mapid, :zabbix_connection_id, :active_base_layer)
  end

  def network_map_payload(network_map)
    NetworkMaps::PayloadBuilder.new(network_map:).call
  end
end
