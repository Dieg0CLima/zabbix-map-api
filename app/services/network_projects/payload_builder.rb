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
        sites: sites_payload,
        nodes: nodes_payload,
        cables: cables_payload
      }
    end

    private

    def sites_payload
      @project.sites.order(:id).map do |site|
        {
          id: site.external_id,
          name: site.name,
          lat: site.lat,
          lng: site.lng,
          color: site.color,
          metadata: site.metadata
        }
      end
    end

    def nodes_payload
      @project.map_nodes.order(:id).map do |node|
        {
          id: node.external_id,
          site_id: node.site&.external_id,
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
          source_site_id: cable.source_site&.external_id,
          target_site_id: cable.target_site&.external_id,
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
