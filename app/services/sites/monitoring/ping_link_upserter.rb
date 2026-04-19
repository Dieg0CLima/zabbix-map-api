module Sites
  module Monitoring
    class PingLinkUpserter
      def initialize(network_map:, site:, device_id:, zabbix_item_id: nil, alias_name: nil)
        @network_map = network_map
        @site = site
        @device_id = device_id
        @zabbix_item_id = zabbix_item_id
        @alias_name = alias_name
      end

      def call
        map_node = find_site_map_node!
        device = find_site_device!
        profile = resolve_profile!(device)
        target_item = resolve_target_item!(profile)

        validate_connection!(target_item)
        validate_item_belongs_to_host!(profile, target_item)
        validate_icmp_item!(target_item)

        replaced_count = 0
        map_node_item = nil

        MapNodeItem.transaction do
          replaced_count = remove_previous_icmp_links!(map_node, target_item: target_item)
          map_node_item = upsert_map_node_item!(map_node, target_item)
        end

        {
          map_node_item: map_node_item,
          replaced_count: replaced_count,
          device: device
        }
      end

      private

      attr_reader :network_map, :site, :device_id, :zabbix_item_id, :alias_name

      def find_site_map_node!
        map_node = network_map.map_nodes.find_by(mappable: site)
        return map_node if map_node

        raise ValidationError.new(
          "Site não está anexado ao mapa informado",
          source: :site_id
        )
      end

      def find_site_device!
        device = site.devices.find_by(id: device_id)
        return device if device

        raise ValidationError.new(
          "Dispositivo não pertence ao site informado",
          source: :device_id
        )
      end

      def resolve_profile!(device)
        profile = device.monitoring_profile
        profile ||= Devices::MonitoringProfileSync.new(device: device).call if device.zabbix_host_link.present?
        return profile if profile&.linked?

        raise ValidationError.new(
          "Dispositivo não possui host Zabbix vinculado para monitoramento",
          source: :device_id
        )
      end

      def resolve_target_item!(profile)
        if zabbix_item_id.present?
          item = profile.zabbix_connection.zabbix_items.find_by(id: zabbix_item_id)
          return item if item

          raise ValidationError.new(
            "Item Zabbix informado não foi encontrado na conexão do dispositivo",
            source: :zabbix_item_id
          )
        end

        fallback_item(profile)
      end

      def fallback_item(profile)
        host = profile.zabbix_connection.zabbix_hosts.find_by(hostid: profile.zabbix_hostid.to_s)
        unless host
          raise ValidationError.new(
            "Host Zabbix do dispositivo não foi encontrado no cache local",
            source: :device_id
          )
        end

        item = profile.zabbix_connection
                      .zabbix_items
                      .where(zabbix_host_id: host.id)
                      .order(:id)
                      .find { |candidate| PingItemMatcher.icmp_ping_item?(candidate) }
        return item if item

        raise ValidationError.new(
          "Nenhum item ICMP Ping foi encontrado para o dispositivo selecionado",
          source: :zabbix_item_id
        )
      end

      def validate_connection!(target_item)
        return if network_map.zabbix_connection_id.blank?
        return if network_map.zabbix_connection_id == target_item.zabbix_connection_id

        raise ValidationError.new(
          "Item Zabbix deve pertencer à conexão configurada no mapa",
          source: :zabbix_item_id
        )
      end

      def validate_item_belongs_to_host!(profile, target_item)
        expected_hostid = profile.zabbix_hostid.to_s
        item_hostid = target_item.host&.hostid.to_s
        return if expected_hostid.blank? || item_hostid == expected_hostid

        raise ValidationError.new(
          "Item Zabbix não pertence ao host vinculado ao dispositivo",
          source: :zabbix_item_id
        )
      end

      def validate_icmp_item!(target_item)
        return if PingItemMatcher.icmp_ping_item?(target_item)

        raise ValidationError.new(
          "Apenas itens ICMP Ping podem ser vinculados ao site",
          source: :zabbix_item_id
        )
      end

      def remove_previous_icmp_links!(map_node, target_item:)
        target_kind = PingItemMatcher.icmp_metric_kind(target_item)
        removable = map_node
                    .map_node_items
                    .includes(:zabbix_item)
                    .select do |item|
          next false if item.zabbix_item_id == target_item.id

          item_kind = PingItemMatcher.icmp_metric_kind(item.zabbix_item)
          item_kind.present? && item_kind == target_kind
        end

        removable.each(&:destroy!)
        removable.size
      end

      def upsert_map_node_item!(map_node, target_item)
        item = map_node.map_node_items.find_or_initialize_by(zabbix_item: target_item)
        item.display_order = next_display_order(map_node) if item.new_record?
        item.alias = alias_name.presence || default_alias(target_item)
        item.save!
        item
      end

      def default_alias(target_item)
        case PingItemMatcher.icmp_metric_kind(target_item)
        when :loss
          "ICMP Loss"
        when :response_time
          "ICMP Response Time"
        else
          "ICMP Ping"
        end
      end

      def next_display_order(map_node)
        map_node.map_node_items.maximum(:display_order).to_i + 1
      end
    end
  end
end
