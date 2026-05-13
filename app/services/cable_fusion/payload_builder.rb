module CableFusion
  class PayloadBuilder
    def initialize(diagram:, validation: nil)
      @diagram = diagram
      @validation = validation
    end

    def call
      {
        id: @diagram.id,
        network_cable_id: @diagram.network_cable_id,
        status: @diagram.status,
        version: @diagram.version,
        published_at: @diagram.published_at,
        last_validated_at: @diagram.last_validated_at,
        validation_errors_count: @diagram.validation_errors_count,
        nodes: nodes_payload,
        ports: ports_payload,
        links: links_payload,
        validation: {
          is_valid: @validation ? @validation.valid? : @diagram.validation_errors_count.to_i.zero?,
          errors: @validation ? @validation.errors : []
        }
      }
    end

    private

    def nodes_payload
      @diagram.nodes.order(:id).map do |node|
        {
          id: node.id,
          client_id: node.client_ref,
          type: node.node_type,
          label: node.label,
          x: node.x,
          y: node.y,
          rotation: node.rotation,
          metadata: node.metadata || {}
        }
      end
    end

    def ports_payload
      @diagram.ports.order(:id).map do |port|
        {
          id: port.id,
          client_id: port.client_ref,
          node_id: port.node_id,
          name: port.name,
          port_type: port.port_type,
          capacity: port.capacity,
          occupancy_limit: port.occupancy_limit,
          position_x: port.position_x,
          position_y: port.position_y,
          metadata: port.metadata || {}
        }
      end
    end

    def links_payload
      @diagram.links.order(:id).map do |link|
        {
          id: link.id,
          client_id: link.client_ref,
          source_port_id: link.source_port_id,
          target_port_id: link.target_port_id,
          link_kind: link.link_kind,
          fiber_side: link.fiber_side,
          fiber_number: link.fiber_number,
          status: link.status,
          metadata: link.metadata || {}
        }
      end
    end
  end
end
