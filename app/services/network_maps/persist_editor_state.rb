class NetworkMaps::PersistEditorState
  def initialize(network_map:, payload:)
    @network_map = network_map
    @payload = payload
    @pop_by_external_id = {}
    @node_by_external_id = {}
  end

  def call
    ActiveRecord::Base.transaction do
      update_map!
      replace_pops!
      replace_nodes!
      replace_cables!
      create_snapshot!
    end

    @network_map.reload
  end

  private

  def update_map!
    @network_map.update!(
      active_base_layer: @payload[:active_base_layer] || @network_map.active_base_layer
    )
  end

  def replace_pops!
    @network_map.map_pops.destroy_all

    pops_payload.each do |pop|
      record = @network_map.map_pops.create!(
        external_id: pop[:id],
        name: pop[:name],
        lat: pop[:lat],
        lng: pop[:lng],
        color: pop[:color],
        metadata: pop[:metadata] || {}
      )

      @pop_by_external_id[record.external_id] = record
    end
  end

  def replace_nodes!
    @network_map.map_nodes.destroy_all

    nodes_payload.each do |node|
      record = @network_map.map_nodes.create!(
        external_id: node[:id],
        map_pop: @pop_by_external_id[node[:pop_id]],
        label: node[:label],
        node_kind: node[:node_kind] || "switch",
        x: node[:lat],
        y: node[:lng],
        lat: node[:lat],
        lng: node[:lng],
        icon: node[:icon],
        color: node[:color],
        size: node[:size],
        metadata: node[:metadata] || {},
        zabbix_ref: node[:zabbix_ref]
      )

      @node_by_external_id[record.external_id] = record
    end
  end

  def replace_cables!
    @network_map.network_cables.destroy_all

    cables_payload.each do |cable|
      record = @network_map.network_cables.create!(
        external_id: cable[:id],
        label: cable[:label],
        cable_type: cable[:cable_type] || "manual",
        status: cable[:status] || "planned",
        color: cable[:color],
        weight: cable[:weight],
        pattern: cable[:pattern],
        source_pop: @pop_by_external_id[cable[:source_pop_id]],
        target_pop: @pop_by_external_id[cable[:target_pop_id]],
        source_node: @node_by_external_id[cable[:source_node_id]],
        target_node: @node_by_external_id[cable[:target_node_id]],
        metadata: cable[:metadata] || {}
      )

      Array(cable[:points]).each_with_index do |point, index|
        record.network_cable_points.create!(
          position: point[:position] || index,
          x: point[:lat],
          y: point[:lng]
        )
      end
    end
  end

  def create_snapshot!
    @network_map.network_map_snapshots.create!(
      label: @payload[:history_label].presence || "Autosave",
      state: {
        active_base_layer: @network_map.active_base_layer,
        pops: pops_payload,
        markers: nodes_payload,
        edges: cables_payload,
        draft_cable: @payload[:draft_cable],
        history_index: @payload[:history_index]
      }
    )
  end

  def pops_payload
    Array(@payload[:pops])
  end

  def nodes_payload
    Array(@payload[:markers])
  end

  def cables_payload
    Array(@payload[:edges])
  end
end
