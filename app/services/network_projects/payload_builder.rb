module NetworkProjects
  class PayloadBuilder
    def initialize(project:)
      @project = project
    end

    def call
      {
        id: @project.id,
        organization_id: @project.organization_id,
        name: @project.name,
        description: @project.description,
        active_base_layer: @project.active_base_layer,
        pops: pops_payload,
        nodes: nodes_payload,
        cables: cables_payload
      }
    end

    private

    def pops_payload
      @project.map_pops.order(:id).map do |pop|
        {
          id: pop.external_id,
          name: pop.name,
          lat: pop.lat,
          lng: pop.lng,
          color: pop.color,
          metadata: pop.metadata
        }
      end
    end

    def nodes_payload
      @project.map_nodes.order(:id).map do |node|
        {
          id: node.external_id,
          pop_id: node.map_pop&.external_id,
          label: node.label,
          node_kind: node.node_kind,
          lat: node.lat,
          lng: node.lng,
          icon: node.icon,
          color: node.color,
          size: node.size,
          metadata: node.metadata
        }
      end
    end

    def cables_payload
      @project.network_cables.order(:id).map do |cable|
        {
          id: cable.external_id,
          source_pop_id: cable.source_pop&.external_id,
          target_pop_id: cable.target_pop&.external_id,
          source_node_id: cable.source_node&.external_id,
          target_node_id: cable.target_node&.external_id,
          color: cable.color,
          weight: cable.weight,
          pattern: cable.pattern,
          points: cable.network_cable_points.order(:position).map do |point|
            {
              position: point.position,
              lat: point.x,
              lng: point.y
            }
          end
        }
      end
    end
  end
end
