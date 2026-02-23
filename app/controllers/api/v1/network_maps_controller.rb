class Api::V1::NetworkMapsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    maps = if admin_without_organization_context?
      NetworkMap.includes(:map_pops, map_nodes: :map_pop, network_cables: :network_cable_points)
    else
      current_organization.network_maps.includes(:map_pops, map_nodes: :map_pop, network_cables: :network_cable_points)
    end

    render json: { data: maps.map { |map| network_map_payload(map) } }, status: :ok
  end

  def show
    render json: { data: network_map_payload(@network_map) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    network_map = current_organization.network_maps.new(network_map_params)

    if network_map.save
      render json: { data: network_map_payload(network_map) }, status: :created
    else
      render json: { errors: network_map.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @network_map.update(network_map_params)
      render json: { data: network_map_payload(@network_map) }, status: :ok
    else
      render json: { errors: @network_map.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @network_map.destroy

    head :no_content
  end

  private

  def set_network_map
    maps_scope = if admin_without_organization_context?
      NetworkMap
    else
      current_organization.network_maps
    end

    @network_map = maps_scope.find(params[:id])
  end

  def network_map_params
    params.require(:network_map).permit(:name, :description, :source_type, :zabbix_mapid, :zabbix_connection_id, :active_base_layer)
  end

  def network_map_payload(network_map)
    {
      id: network_map.id,
      organization_id: network_map.organization_id,
      name: network_map.name,
      description: network_map.description,
      source_type: network_map.source_type,
      zabbix_mapid: network_map.zabbix_mapid,
      zabbix_connection_id: network_map.zabbix_connection_id,
      active_base_layer: network_map.active_base_layer,
      pops: network_map.map_pops.order(:id).map do |pop|
        {
          id: pop.external_id || pop.id,
          name: pop.name,
          lat: pop.lat,
          lng: pop.lng,
          color: pop.color,
          metadata: pop.metadata
        }
      end,
      nodes: network_map.map_nodes.order(:id).map do |node|
        {
          id: node.external_id || node.id,
          pop_id: node.map_pop&.external_id || node.map_pop_id,
          label: node.label,
          node_kind: node.node_kind,
          x: node.x,
          y: node.y,
          lat: node.lat,
          lng: node.lng,
          icon: node.icon,
          color: node.color,
          size: node.size,
          zabbix_ref: node.zabbix_ref,
          metadata: node.metadata
        }
      end,
      cables: network_map.network_cables.order(:id).map do |cable|
        {
          id: cable.external_id || cable.id,
          source_pop_id: cable.source_pop&.external_id || cable.source_pop_id,
          target_pop_id: cable.target_pop&.external_id || cable.target_pop_id,
          source_node_id: cable.source_node&.external_id || cable.source_node_id,
          target_node_id: cable.target_node&.external_id || cable.target_node_id,
          label: cable.label,
          cable_type: cable.cable_type,
          status: cable.status,
          bandwidth_mbps: cable.bandwidth_mbps,
          length_meters: cable.length_meters,
          color: cable.color,
          weight: cable.weight,
          pattern: cable.pattern,
          metadata: cable.metadata,
          points: cable.network_cable_points.order(:position).map do |point|
            {
              id: point.id,
              position: point.position,
              x: point.x,
              y: point.y
            }
          end
        }
      end
    }
  end
end
