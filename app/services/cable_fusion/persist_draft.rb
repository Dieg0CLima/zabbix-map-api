require "digest"

module CableFusion
  class PersistDraft
    def initialize(diagram:, payload:, actor: nil)
      @diagram = diagram
      @payload = payload.deep_symbolize_keys
      @actor = actor
    end

    def call
      ActiveRecord::Base.transaction do
        replace_nodes!
        replace_links!
        validation = CableFusion::ValidateDraft.new(diagram: @diagram.reload).call

        @diagram.update!(
          status: validation.valid? ? "draft" : "invalid",
          last_validated_at: Time.current,
          validation_errors_count: validation.errors.size,
          structure_checksum: structure_checksum
        )

        [ @diagram.reload, validation ]
      end
    end

    private

    def replace_nodes!
      @diagram.links.destroy_all
      @diagram.nodes.destroy_all

      node_refs = {}
      port_refs = {}

      Array(@payload[:nodes]).each do |node_payload|
        node = @diagram.nodes.create!(
          client_ref: node_payload[:client_id],
          node_type: node_payload[:type],
          label: node_payload[:label],
          x: node_payload[:x] || 0.0,
          y: node_payload[:y] || 0.0,
          rotation: node_payload[:rotation] || 0.0,
          metadata: node_payload[:metadata] || {}
        )
        node_refs[node_payload[:client_id].to_s] = node.id if node_payload[:client_id].present?
      end

      Array(@payload[:ports]).each do |port_payload|
        node_id = resolve_node_id(port_payload, node_refs)
        next if node_id.blank?

        port = CableFusion::Port.create!(
          node_id:,
          client_ref: port_payload[:client_id],
          name: port_payload[:name],
          port_type: port_payload[:port_type],
          capacity: port_payload[:capacity] || 1,
          occupancy_limit: port_payload[:occupancy_limit] || 1,
          position_x: port_payload[:position_x],
          position_y: port_payload[:position_y],
          metadata: port_payload[:metadata] || {}
        )
        port_refs[port_payload[:client_id].to_s] = port.id if port_payload[:client_id].present?
      end

      @port_refs = port_refs
    end

    def replace_links!
      Array(@payload[:links]).each do |link_payload|
        source_port_id = resolve_port_id(link_payload[:source_port_id], link_payload[:source_port_client_id])
        target_port_id = resolve_port_id(link_payload[:target_port_id], link_payload[:target_port_client_id])
        next if source_port_id.blank? || target_port_id.blank?

        @diagram.links.create!(
          client_ref: link_payload[:client_id],
          source_port_id:,
          target_port_id:,
          link_kind: link_payload[:link_kind] || "splice",
          fiber_side: link_payload[:fiber_side],
          fiber_number: link_payload[:fiber_number],
          status: link_payload[:status] || "draft",
          metadata: link_payload[:metadata] || {}
        )
      end
    end

    def resolve_node_id(port_payload, node_refs)
      node_id = port_payload[:node_id]
      return node_id if node_id.present?

      node_refs[port_payload[:node_client_id].to_s]
    end

    def resolve_port_id(id_value, client_id_value)
      return id_value if id_value.present?

      @port_refs[client_id_value.to_s]
    end

    def structure_checksum
      Digest::SHA256.hexdigest(@payload.to_json)
    end
  end
end
