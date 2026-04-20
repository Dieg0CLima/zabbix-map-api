module Sites
  module Monitoring
    class PingLinkCatalog
      FETCH_LIMIT = 2_000

      def initialize(network_map:, site:)
        @network_map = network_map
        @site = site
      end

      def call
        live_values = Zabbix::LiveValuesFetcher.new(items: linked_zabbix_items + candidate_zabbix_items).call

        {
          map_node_id: site_map_node&.id,
          linked_item: linked_item_payload(live_values),
          linked_items: linked_items_payload(live_values),
          candidates: candidate_payload(live_values)
        }
      end

      private

      attr_reader :network_map, :site

      def site_map_node
        @site_map_node ||= network_map.map_nodes.includes(map_node_items: :zabbix_item).find_by(mappable: site)
      end

      def linked_item_payload(live_values)
        linked = linked_map_node_items.find do |item|
          PingItemMatcher.icmp_metric_kind(item.zabbix_item) == :ping
        end || linked_map_node_items.first
        return nil unless linked

        attach_live_snapshot!(MapNodeItems::PayloadBuilder.new(map_node_item: linked).call, live_values, linked.zabbix_item)
      end

      def linked_items_payload(live_values)
        linked_map_node_items.map do |map_node_item|
          payload = MapNodeItems::PayloadBuilder.new(map_node_item: map_node_item).call
          attach_live_snapshot!(payload, live_values, map_node_item.zabbix_item)
        end
      end

      def linked_map_node_items
        @linked_map_node_items ||= begin
          items = site_map_node&.map_node_items&.to_a || []
          items
            .select { |item| PingItemMatcher.icmp_metric_item?(item.zabbix_item) }
            .sort_by { |item| [PingItemMatcher::METRIC_KIND_PRIORITY.fetch(PingItemMatcher.icmp_metric_kind(item.zabbix_item), 99), item.display_order.to_i, item.id.to_i] }
        end
      end

      def candidate_payload(live_values)
        site.devices.includes(:zabbix_host_link, monitoring_profile: { device_monitoring_items: :zabbix_item }).flat_map do |device|
          candidates_for_device(device, live_values)
        end
      end

      def candidates_for_device(device, live_values)
        profile = device.monitoring_profile
        profile ||= Devices::MonitoringProfileSync.new(device: device).call if device.zabbix_host_link.present?
        return [] unless profile&.linked?

        items = device_ping_items(device)

        items.map do |item|
          live = live_values[item.itemid.to_s] || {}
          {
            device: {
              id: device.id,
              name: device.name
            },
            metric_kind: PingItemMatcher.icmp_metric_kind(item)&.to_s,
            zabbix_item_id: item.id,
            itemid: item.itemid,
            name: item.name,
            key_: item.key_,
            units: item.units,
            lastvalue: (live["value"] || item.lastvalue),
            lastclock: (live["clock"] || item.lastclock)&.to_s,
            lastns: live["ns"]&.to_s,
            lastclock_iso: clock_to_iso(live["clock"] || item.lastclock),
            data_source: live.present? ? "live" : "cache"
          }
        end
      end

      def linked_zabbix_items
        linked_map_node_items.filter_map(&:zabbix_item)
      end

      def candidate_zabbix_items
        @candidate_zabbix_items ||= site.devices.includes(:zabbix_host_link, monitoring_profile: { device_monitoring_items: :zabbix_item }).flat_map do |device|
          device_ping_items(device)
        end
      end

      def attach_live_snapshot!(payload, live_values, zabbix_item = nil)
        zabbix_item_payload = payload[:zabbix_item]
        return payload unless zabbix_item_payload

        live = live_values[zabbix_item_payload[:itemid].to_s] || {}
        zabbix_item_payload[:metric_kind] = PingItemMatcher.icmp_metric_kind(zabbix_item)&.to_s
        zabbix_item_payload[:lastvalue] = live["value"] || zabbix_item_payload[:lastvalue]
        zabbix_item_payload[:lastclock] = (live["clock"] || zabbix_item_payload[:lastclock])&.to_s
        zabbix_item_payload[:lastns] = live["ns"]&.to_s
        zabbix_item_payload[:lastclock_iso] = clock_to_iso(zabbix_item_payload[:lastclock])
        zabbix_item_payload[:data_source] = live.present? ? "live" : "cache"
        payload
      end

      def clock_to_iso(clock)
        return nil if clock.blank?

        Time.zone.at(clock.to_i).utc.iso8601
      rescue StandardError
        nil
      end

      def device_ping_items(device)
        @device_ping_items ||= {}
        return @device_ping_items[device.id] if @device_ping_items.key?(device.id)

        profile = device.monitoring_profile
        profile ||= Devices::MonitoringProfileSync.new(device: device).call if device.zabbix_host_link.present?
        return @device_ping_items[device.id] = [] unless profile&.linked?

        raw_items = ZabbixHosts::ItemsFetcher.new(
          connection: profile.zabbix_connection,
          hostid: profile.zabbix_hostid,
          limit: FETCH_LIMIT
        ).call

        item_ids = raw_items.filter_map { |item| item[:value].presence&.to_i }.uniq
        items_by_id = profile.zabbix_connection.zabbix_items.where(id: item_ids).index_by(&:id)

        @device_ping_items[device.id] = raw_items.filter_map do |raw|
          item = items_by_id[raw[:value].to_i]
          next unless item
          next unless PingItemMatcher.icmp_metric_item?(item)

          item
        end
      rescue ZabbixHosts::ItemsFetcher::Error
        @device_ping_items[device.id] = []
      end
    end
  end
end
