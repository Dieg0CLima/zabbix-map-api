class NetworkMaps::EditorStatePayloadBuilder
  def initialize(network_map:)
    @network_map = network_map
  end

  def call
    {
      network_map_id:    @network_map.id,
      active_base_layer: @network_map.active_base_layer,
      history_label:     latest_snapshot&.label,
      history_index:     latest_state["history_index"],
      draft_cable:       latest_state["draft_cable"],
      elements:          elements_payload,
      edges:             edge_payload,
      snapshots:         snapshots_payload
    }
  end

  private

  def latest_snapshot
    @latest_snapshot ||= @network_map.network_map_snapshots.order(created_at: :desc).first
  end

  def latest_state
    latest_snapshot&.state || {}
  end

  def elements_payload
    @network_map
      .map_elements
      .includes(:mappable)
      .order(:display_order, :id)
      .map { |el| MapElements::PayloadBuilder.new(map_element: el).call }
  end

  def edge_payload
    @network_map.network_cables
                .includes(:network_cable_points, :source_element, :target_element)
                .order(:id)
                .map { |cable| edge_attrs(cable) }
  end

  def edge_attrs(cable)
    {
      id:                cable.external_id,
      label:             cable.label,
      cable_type:        cable.cable_type,
      status:            cable.status,
      source_element_id: cable.source_element&.external_id,
      target_element_id: cable.target_element&.external_id,
      color:             cable.color,
      weight:            cable.weight,
      pattern:           cable.pattern,
      metadata:          cable.metadata,
      points:            cable.network_cable_points.order(:position).map do |point|
        {
          position: point.position,
          lat:      point.x.to_f,
          lng:      point.y.to_f
        }
      end
    }
  end

  def snapshots_payload
    @network_map.network_map_snapshots.order(created_at: :desc).limit(20).map do |snapshot|
      {
        id:         snapshot.id,
        label:      snapshot.label,
        created_at: snapshot.created_at,
        state:      snapshot.state
      }
    end
  end
end
