module Sites
  module Monitoring
    class PingLinkRemover
      def initialize(network_map:, site:)
        @network_map = network_map
        @site = site
      end

      def call
        map_node = network_map.map_nodes.includes(map_node_items: :zabbix_item).find_by(mappable: site)
        return 0 unless map_node

        removable = map_node.map_node_items.select do |item|
          PingItemMatcher.icmp_ping_item?(item.zabbix_item)
        end

        removable.each(&:destroy!)
        removable.size
      end

      private

      attr_reader :network_map, :site
    end
  end
end
