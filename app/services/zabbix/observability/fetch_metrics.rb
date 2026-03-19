class Zabbix::Observability::FetchMetrics < Zabbix::Observability::BaseFetch
  def call
    with_cache("metrics") do
      safe_fetch(default: default_payload) do
        items = fetch_items
        mapper = Zabbix::Observability::ItemMapper.new(items)
        traffic = build_traffic(mapper.traffic_items)

        {
          traffic:,
          cpu: build_scalar_metric(mapper.cpu_item),
          memory: build_scalar_metric(mapper.memory_item),
          zabbix_unavailable: false
        }
      end
    end
  end

  private

  def default_payload
    {
      traffic: [],
      cpu: { usage: nil },
      memory: { usage: nil }
    }
  end

  def fetch_items
    if database_available?
      Zabbix::DatabaseItemsFetcher.new(connection:, hostid: host_id, limit: 500, include_tags: false).call.map do |item|
        {
          "itemid" => item[:itemid],
          "name" => item[:name],
          "key_" => item[:key_],
          "lastvalue" => item[:lastvalue],
          "lastclock" => item[:lastclock]&.to_i.to_s,
          "units" => item[:units],
          "value_type" => item[:value_type],
          "description" => item[:description],
          "tags" => item[:tags].map { |tag| { "tag" => tag[:tag], "value" => tag[:value] } }
        }
      end
    elsif api_available?
      client.call("item.get", {
        hostids: [host_id],
        webitems: true,
        monitored: true,
        output: ["itemid", "name", "key_", "lastvalue", "lastclock", "units", "value_type", "description"],
        selectTags: "extend",
        sortfield: "name"
      })
    else
      []
    end
  end

  def build_traffic(items)
    grouped = items.group_by { |item| item["__interface_name"] }

    grouped.map do |interface_name, interface_items|
      in_item = interface_items.find { |item| item["__direction"] == :in }
      out_item = interface_items.find { |item| item["__direction"] == :out }
      timestamp = [in_item, out_item].compact.max_by { |item| item["lastclock"].to_i }&.fetch("lastclock", nil)

      {
        interface: interface_name,
        in_bps: normalize_bps(in_item),
        out_bps: normalize_bps(out_item),
        timestamp: timestamp ? parse_time(timestamp) : nil
      }
    end.sort_by { |entry| entry[:interface] }
  end

  def build_scalar_metric(item)
    { usage: normalize_percentage(item) }
  end

  def normalize_bps(item)
    return nil if item.blank?

    value = item["lastvalue"].to_f
    units = item["units"].to_s.downcase

    return value.round if units.include?("bps") || units.include?("b/s")
    return (value * 8).round if units.include?("bps") == false && (item["key_"].to_s.match?(/octets/i) || units.include?("b") || units.include?("bytes"))

    value.round
  end

  def normalize_percentage(item)
    return nil if item.blank?

    item["lastvalue"].to_f.round
  end
end
