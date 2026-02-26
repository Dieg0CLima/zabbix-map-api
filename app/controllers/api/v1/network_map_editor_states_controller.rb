class Api::V1::NetworkMapEditorStatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_network_map
  before_action :require_editor_or_admin!, only: :update

  def show
    render json: { data: editor_payload(@network_map) }, status: :ok
  end

  def update
    network_map = NetworkMaps::PersistEditorState.new(network_map: @network_map, payload: editor_state_params).call

    render json: { data: editor_payload(network_map) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  private

  def set_network_map
    maps_scope = if admin_without_organization_context?
      NetworkMap
    else
      current_organization.network_maps
    end

    @network_map = maps_scope.includes(:map_pops, map_nodes: :map_pop, network_cables: :network_cable_points).find(params[:network_map_id])
  end

  def editor_state_params
    params.require(:editor_state).permit(
      :active_base_layer,
      :history_label,
      :history_index,
      draft_cable: {},
      pops: [ :id, :name, :lat, :lng, :color, { metadata: {} } ],
      markers: [ :id, :label, :node_kind, :lat, :lng, :icon, :color, :size, :zabbix_ref, :pop_id, { metadata: {} } ],
      edges: [ :id, :label, :cable_type, :status, :color, :weight, :pattern, :source_pop_id, :target_pop_id, :source_node_id, :target_node_id,
               { metadata: {} }, { points: [ :position, :lat, :lng ] } ]
    )
  end

  def editor_payload(network_map)
    latest_snapshot = network_map.network_map_snapshots.order(created_at: :desc).first
    latest_state = latest_snapshot&.state || {}

    {
      network_map_id: network_map.id,
      active_base_layer: network_map.active_base_layer,
      history_label: latest_snapshot&.label,
      history_index: latest_state["history_index"],
      draft_cable: latest_state["draft_cable"],
      pops: network_map.map_pops.order(:id).map do |pop|
        {
          id: pop.external_id,
          name: pop.name,
          lat: pop.lat.to_f,
          lng: pop.lng.to_f,
          color: pop.color,
          metadata: pop.metadata
        }
      end,
      markers: network_map.map_nodes.order(:id).map do |node|
        {
          id: node.external_id,
          pop_id: node.map_pop&.external_id,
          label: node.label,
          node_kind: node.node_kind,
          lat: node.lat.to_f,
          lng: node.lng.to_f,
          icon: node.icon,
          color: node.color,
          size: node.size,
          zabbix_ref: node.zabbix_ref,
          metadata: node.metadata
        }
      end,
      edges: network_map.network_cables.order(:id).map do |cable|
        {
          id: cable.external_id,
          label: cable.label,
          cable_type: cable.cable_type,
          status: cable.status,
          source_pop_id: cable.source_pop&.external_id,
          target_pop_id: cable.target_pop&.external_id,
          source_node_id: cable.source_node&.external_id,
          target_node_id: cable.target_node&.external_id,
          color: cable.color,
          weight: cable.weight,
          pattern: cable.pattern,
          metadata: cable.metadata,
          points: cable.network_cable_points.order(:position).map do |point|
            {
              position: point.position,
              lat: point.x.to_f,
              lng: point.y.to_f
            }
          end
        }
      end,
      snapshots: network_map.network_map_snapshots.order(created_at: :desc).limit(20).map do |snapshot|
        {
          id: snapshot.id,
          label: snapshot.label,
          created_at: snapshot.created_at,
          state: snapshot.state
        }
      end
    }
  end
end
