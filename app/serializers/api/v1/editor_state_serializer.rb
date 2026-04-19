class Api::V1::EditorStateSerializer
  def initialize(map:, elements:, sites:, devices:, zabbix_summary:, capabilities:)
    @map = map
    @elements = elements
    @sites = sites
    @devices = devices
    @zabbix_summary = zabbix_summary
    @capabilities = capabilities
    @site_ping_visual_by_node_id = build_site_ping_visual_by_node_id
  end

  def as_json(*)
    {
      map: Api::V1::NetworkMapSerializer.new(@map).as_json,
      elements: @elements.map do |element|
        Api::V1::MapElementSerializer.new(
          element,
          site_ping_visual: @site_ping_visual_by_node_id[element.id]
        ).as_json
      end,
      sites: @sites.map { |site| Api::V1::SiteSerializer.new(site).as_json },
      devices: @devices.map { |device| Api::V1::DeviceSerializer.new(device).as_json },
      zabbix_summary: @zabbix_summary,
      capabilities: @capabilities
    }
  end

  private

  def build_site_ping_visual_by_node_id
    site_metrics_by_node_id = @elements.filter_map do |node|
      next unless node.mappable_type == "Site"

      metric_items = build_metric_items_by_kind(node)
      next if metric_items.empty?

      [ node.id, metric_items ]
    end

    return {} if site_metrics_by_node_id.empty?

    all_metric_items = site_metrics_by_node_id.flat_map { |(_, metrics_by_kind)| metrics_by_kind.values }.uniq
    live_values = Zabbix::LiveValuesFetcher.new(items: all_metric_items).call

    site_metrics_by_node_id.each_with_object({}) do |(node_id, metric_items_by_kind), acc|
      acc[node_id] = Sites::Monitoring::StatusResolver.new(
        metric_items_by_kind: metric_items_by_kind,
        live_values: live_values
      ).call
    end
  end

  def build_metric_items_by_kind(node)
    items = node.map_node_items
                .sort_by { |map_node_item| [ map_node_item.display_order.to_i, map_node_item.id.to_i ] }
                .filter_map(&:zabbix_item)

    items.each_with_object({}) do |zabbix_item, acc|
      kind = Sites::Monitoring::PingItemMatcher.icmp_metric_kind(zabbix_item)
      next unless kind

      acc[kind] ||= zabbix_item
    end
  end
end
