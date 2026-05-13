module NetworkMaps
  class PayloadBuilder
    HOST_ITEM_LIMIT = 4

    def initialize(network_map:)
      @network_map = network_map
      @zabbix_connection = network_map.zabbix_connection
      @zabbix_hosts = []
      @hosts_by_id = {}
      @hosts_by_hostid = {}
      preload_collections
    end

    def call
      payload = base_payload
      payload[:pops] = pops_payload
      payload[:nodes] = nodes_payload
      payload[:cables] = cables_payload
      payload[:layers] = layers_payload
      payload[:filters] = filters_payload
      payload[:zabbix_context] = zabbix_context_payload
      payload
    end

    private

    attr_reader :pops, :nodes, :cables, :zabbix_connection

    def preload_collections
      @pops = @network_map.map_pops.order(:id).to_a
      @nodes = @network_map.map_nodes.includes(:map_pop, :zabbix_host).order(:id).to_a
      @cables = @network_map.network_cables.includes(:network_cable_points, source_node: :zabbix_host, target_node: :zabbix_host).order(:id).to_a
      preload_zabbix_hosts
    end

    def preload_zabbix_hosts
      return unless zabbix_connection
      host_ids = nodes.map(&:zabbix_host_id).compact
      host_refs = nodes.map(&:zabbix_ref).compact
      host_records = []

      if host_ids.any?
        host_records += Zabbix::Host.where(zabbix_connection: zabbix_connection, id: host_ids).includes(:items).to_a
      end

      if host_refs.any?
        host_records += Zabbix::Host.where(zabbix_connection: zabbix_connection, hostid: host_refs).includes(:items).to_a
      end

      @zabbix_hosts = host_records.uniq { |record| record.id }
      @hosts_by_id = @zabbix_hosts.index_by(&:id)
      @hosts_by_hostid = @zabbix_hosts.index_by(&:hostid)
    end

    def base_payload
      {
        id: @network_map.id,
        organization_id: @network_map.organization_id,
        name: @network_map.name,
        description: @network_map.description,
        source_type: @network_map.source_type,
        zabbix_mapid: @network_map.zabbix_mapid,
        zabbix_connection_id: @network_map.zabbix_connection_id,
        active_base_layer: @network_map.active_base_layer,
        metadata: @network_map.metadata,
        created_at: @network_map.created_at,
        updated_at: @network_map.updated_at
      }
    end

    def pops_payload
      pops.map do |pop|
        {
          id: pop.external_id || pop.id,
          name: pop.name,
          lat: pop.lat,
          lng: pop.lng,
          color: pop.color,
          metadata: pop.metadata
        }
      end
    end

    def nodes_payload
      nodes.map do |node|
        host = host_for(node)
        {
          id: node.external_id || node.id,
          pop_id: node.map_pop&.external_id || node.map_pop_id,
          label: node.label,
          node_kind: node.node_kind,
          x: node.x,
          y: node.y,
          lat: node.lat,
          lng: node.lng,
          width: node.width,
          height: node.height,
          label_override: node.label_override,
          icon: node.icon,
          color: node.color,
          size: node.size,
          visible: node.visible,
          collapsed: node.collapsed,
          metadata: node.metadata,
          zabbix_ref: node.zabbix_ref,
          zabbix_host_id: host&.hostid,
          zabbix_status: host_status_label(host),
          zabbix_availability: host_available?(host),
          zabbix_host: host_payload(host),
          zabbix_host_tags: host_tag_labels(host),
          layer: node_layer(node),
          actions: node_actions(host)
        }
      end
    end

    def cables_payload
      cables.map do |cable|
        {
          id: cable.id,
          network_map_id: cable.network_map_id,
          source_pop_id: cable.source_pop&.external_id || cable.source_pop_id,
          target_pop_id: cable.target_pop&.external_id || cable.target_pop_id,
          source_node_id: cable.source_node&.external_id || cable.source_node_id,
          target_node_id: cable.target_node&.external_id || cable.target_node_id,
          label: cable.label,
          cable_type: cable.cable_type,
          status: cable.status,
          zabbix_status: cable_zabbix_status(cable),
          bandwidth_mbps: cable.bandwidth_mbps,
          length_meters: cable.length_meters,
          color: cable.color,
          weight: cable.weight,
          pattern: cable.pattern,
          metadata: cable.metadata,
          points: cable_points_payload(cable),
          layer: cable.metadata["layer"] || "cables",
          actions: cable_actions(cable)
        }
      end
    end

    def cable_points_payload(cable)
      cable.network_cable_points.order(:position).map do |point|
        {
          id: point.id,
          position: point.position,
          x: point.x.to_f,
          y: point.y.to_f,
          lat: point.x.to_f,
          lng: point.y.to_f
        }
      end
    end

    def layers_payload
      {
        pops: {
          label: "PoPs",
          order: 1,
          description: "Pontos de presença documentados",
          data: pops_payload
        },
        nodes: {
          label: "Nós",
          order: 2,
          description: "Equipamentos e entidades com metadados e relações ao Zabbix",
          data: nodes_payload
        },
        cables: {
          label: "Cabos",
          order: 3,
          description: "Linhas e conexões recorrendo a pontos e status monitorados",
          data: cables_payload
        }
      }
    end

    def filters_payload
      {
        pops: pops_payload.map { |pop| { id: pop[:id], name: pop[:name], color: pop[:color], tier: pop[:metadata]["tier"] } },
        node_kinds: nodes_payload.map { |node| node[:node_kind] }.compact.uniq,
        node_statuses: nodes_payload.map { |node| node[:zabbix_status] }.compact.uniq,
        node_tags: nodes_payload.flat_map { |node| Array(node[:zabbix_host_tags]) }.compact.uniq,
        cable_types: cables_payload.map { |cable| cable[:cable_type] }.compact.uniq,
        cable_statuses: cables_payload.map { |cable| cable[:zabbix_status] }.compact.uniq,
        zabbix_statuses: zabbix_status_counts,
        actions: global_actions
      }
    end

    def global_actions
      return [] unless zabbix_connection

      [
        {
          type: "sync_connection",
          label: "Sincronizar conexão Zabbix",
          endpoint: "/api/v1/zabbix_connections/#{zabbix_connection.id}"
        },
        {
          type: "open_connection",
          label: "Abrir painel Zabbix",
          template: zabbix_ui_action_template
        }
      ].compact
    end

    def zabbix_context_payload
      return { connection: nil } unless zabbix_connection

      {
        connection: ZabbixConnections::PayloadBuilder.new(connection: zabbix_connection).call,
        hosts: zabbix_hosts_payload,
        metrics: Zabbix::MetricsFetcher.new(network_map: @network_map).call,
        problems: Zabbix::ProblemFetcher.new(network_map: @network_map).call,
        sync: {
          last_synced_at: zabbix_connection.last_synced_at,
          hosts_count: zabbix_hosts_payload.size
        },
        urls: {
          host_detail: zabbix_host_detail_template,
          host_ui: zabbix_ui_action_template
        }
      }
    end

    def zabbix_hosts_payload
      @zabbix_hosts.to_a.map do |host|
        payload = Zabbix::HostPayloadBuilder.new(host: host).details_payload
        payload.merge(
          tags: Array(host.tags).map { |tag| tag.with_indifferent_access.slice("tag", "value") },
          items_summary: host_items_summary(host),
          status: host_status_label(host),
          availability: host_available?(host)
        )
      end
    end

    def host_for(node)
      return unless zabbix_connection
      return node.zabbix_host if node.zabbix_host.present?
      return hosts_by_hostid[node.zabbix_ref] if hosts_by_hostid
      node.zabbix_host
    end

    def host_payload(host)
      return unless host

      payload = Zabbix::HostPayloadBuilder.new(host: host).details_payload
      payload.merge(
        tags: Array(host.tags).map { |tag| tag.with_indifferent_access.slice("tag", "value") },
        suggested_device_attributes: payload[:suggested_device_attributes],
        metadata: payload[:metadata]
      )
    end

    def host_tag_labels(host)
      return [] unless host

      Array(host.tags).map do |tag|
        tag = tag.with_indifferent_access
        "#{tag[:tag]}:#{tag[:value]}"
      end
    end

    def host_items_summary(host)
      host.items.order(updated_at: :desc).limit(HOST_ITEM_LIMIT).map do |item|
        {
          itemid: item.itemid,
          name: item.name,
          key: item.key_,
          lastvalue: item.lastvalue,
          state: item.state,
          status: item.status,
          units: item.units,
          lastclock: item.lastclock
        }
      end
    end

    def node_layer(node)
      node.metadata["layer"] || node.node_kind || "nodes"
    end

    def node_actions(host)
      return [] unless host && zabbix_connection

      action = {
        type: "open_zabbix_host",
        label: "Abrir host no Zabbix",
        template: zabbix_ui_action_template
      }

      [
        action.compact,
        {
          type: "view_host_detail",
          label: "Ver detalhes do host",
          endpoint: zabbix_host_detail_endpoint(host)
        }
      ]
    end

    def cable_actions(cable)
      [
        {
          type: "inspect_link",
          label: "Ver histórico do link",
          metadata: cable.metadata.slice("owner", "path", "criticality")
        }
      ]
    end

    def zabbix_status_counts
      counts = Hash.new(0)
      nodes_payload.each do |node|
        counts[node[:zabbix_status]] += 1 if node[:zabbix_status]
      end
      counts
    end

    def cable_zabbix_status(cable)
      statuses = [ cable.source_node, cable.target_node ].compact.map { |node| host_status_label(host_for(node)) }.compact
      return "unknown" if statuses.empty?
      return "down" if statuses.include?("down")
      return "degraded" if statuses.include?("degraded")
      statuses.include?("up") ? "up" : statuses.first
    end

    def host_status_label(host)
      return "unknown" unless host
      return "down" if host.status.to_s == "1" || host.status.to_s.casecmp("disabled").zero?
      host_available?(host) ? "up" : "degraded"
    end

    def host_available?(host)
      return nil unless host
      value = host.available
      return value if value == true || value == false
      value.to_s.strip.downcase.in?(%w[1 true up available enabled])
    end

    def hosts_by_hostid
      @hosts_by_hostid || {}
    end

    def zabbix_ui_action_template
      return unless zabbix_connection&.base_url

      base = zabbix_connection.base_url.sub(%r{/api_jsonrpc\.php\z}, "")
      "#{base}/zabbix.php?action=host.detail&hostid=%{hostid}"
    end

    def zabbix_host_detail_endpoint(host)
      return unless zabbix_connection
      "/api/v1/zabbix_connections/#{zabbix_connection.id}/zabbix_hosts/#{host.hostid}"
    end

    def zabbix_host_detail_template
      return unless zabbix_connection
      "/api/v1/zabbix_connections/#{zabbix_connection.id}/zabbix_hosts/%{hostid}"
    end

    def zabbix_connection_payload
      return unless zabbix_connection
      ZabbixConnections::PayloadBuilder.new(connection: zabbix_connection).call
    end
  end
end
