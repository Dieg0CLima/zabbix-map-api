class NetworkMaps::EditorStatePayloadBuilder
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    {
      network_map_id: @network_map.id,
      active_base_layer: @network_map.active_base_layer,
      history_label: latest_snapshot&.label,
      history_index: latest_state["history_index"],
      draft_cable: latest_state["draft_cable"],
      pops: pop_payload,
      markers: marker_payload,
      edges: edge_payload,
      snapshots: snapshots_payload
    }
  end

  private

  def latest_snapshot
    @latest_snapshot ||= @network_map.network_map_snapshots.order(created_at: :desc).first
  end

  def latest_state
    latest_snapshot&.state || {}
  end

  def pop_payload
    @network_map.map_pops.order(:id).map do |pop|
      {
        id: pop.external_id,
        name: pop.name,
        lat: pop.lat.to_f,
        lng: pop.lng.to_f,
        color: pop.color,
        metadata: pop.metadata
      }
    end
  end

  def marker_payload
    @network_map.map_nodes.order(:id).map do |node|
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
    end
  end

  def edge_payload
    @network_map.network_cables.order(:id).map do |cable|
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
    end
  end

  def snapshots_payload
    @network_map.network_map_snapshots.order(created_at: :desc).limit(20).map do |snapshot|
      {
        id: snapshot.id,
        label: snapshot.label,
        created_at: snapshot.created_at,
        state: snapshot.state
      }
    end
  end
end
