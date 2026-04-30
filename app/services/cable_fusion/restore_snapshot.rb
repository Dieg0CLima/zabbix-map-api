module CableFusion
  class RestoreSnapshot
    def initialize(diagram:, snapshot:, actor:)
      @diagram = diagram
      @snapshot = snapshot
      @actor = actor
    end

    def call
      payload = @snapshot.payload.deep_symbolize_keys
      restored_payload = normalized_payload(payload)

      diagram, validation = CableFusion::PersistDraft.new(
        diagram: @diagram,
        payload: restored_payload,
        actor: @actor
      ).call

      CableFusion::CreateSnapshot.new(
        diagram: diagram,
        actor: @actor,
        reason: "restore_from_snapshot:#{@snapshot.id}",
        published: false
      ).call

      [ diagram, validation ]
    end

    private

    def normalized_payload(payload)
      original_nodes = payload.fetch(:nodes, []).map(&:deep_symbolize_keys)
      node_client_ref_by_id = {}
      nodes = original_nodes.map do |node|
        client_ref = node[:client_id].presence || "restore-node-#{node[:id]}"
        node_client_ref_by_id[node[:id]] = client_ref if node[:id].present?

        {
          client_id: client_ref,
          type: node[:type],
          label: node[:label],
          x: node[:x],
          y: node[:y],
          rotation: node[:rotation],
          metadata: node[:metadata] || {}
        }
      end

      original_ports = payload.fetch(:ports, []).map(&:deep_symbolize_keys)
      port_client_ref_by_id = {}
      ports = original_ports.map do |port|
        client_ref = port[:client_id].presence || "restore-port-#{port[:id]}"
        port_client_ref_by_id[port[:id]] = client_ref if port[:id].present?

        {
          client_id: client_ref,
          node_client_id: node_client_ref_by_id[port[:node_id]],
          name: port[:name],
          port_type: port[:port_type],
          capacity: port[:capacity],
          occupancy_limit: port[:occupancy_limit],
          position_x: port[:position_x],
          position_y: port[:position_y],
          metadata: port[:metadata] || {}
        }
      end

      links = payload.fetch(:links, []).map do |link|
        source = link.deep_symbolize_keys
        {
          client_id: source[:client_id].presence || "restore-link-#{source[:id]}",
          source_port_client_id: port_client_ref_by_id[source[:source_port_id]],
          target_port_client_id: port_client_ref_by_id[source[:target_port_id]],
          link_kind: source[:link_kind],
          fiber_side: source[:fiber_side],
          fiber_number: source[:fiber_number],
          status: source[:status],
          metadata: source[:metadata] || {}
        }
      end

      { nodes:, ports:, links: }
    end
  end
end
