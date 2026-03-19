class Zabbix::Observability::FetchRecentData < Zabbix::Observability::BaseFetch
  DEFAULT_LIMIT = 50

  def initialize(device:, limit: DEFAULT_LIMIT, **kwargs)
    super(device:, **kwargs)
    @limit = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
  end

  def call
    with_cache("recent-data") do
      safe_fetch(default: default_payload) do
        items = fetch_items

        {
          host: {
            id: host_id,
            label: device.zabbix_host_label
          },
          items: normalize_items(items),
          total: Array(items).size,
          zabbix_unavailable: false
        }
      end
    end
  end

  private

  def default_payload
    {
      host: {
        id: host_id,
        label: device.zabbix_host_label
      },
      items: [],
      total: 0
    }
  end

  def normalize_items(items)
    Array(items).map do |item|
      {
        id: item["itemid"].to_s,
        host_id: host_id,
        host_label: device.zabbix_host_label,
        name: item["name"].to_s,
        key: item["key_"].to_s,
        last_check_at: parse_time(item["lastclock"]),
        last_check_ago_seconds: [Time.current.to_i - item["lastclock"].to_i, 0].max,
        last_value: format_item_value(item, item["lastvalue"]),
        previous_value: format_item_value(item, item["prevvalue"]),
        change: build_change(item),
        units: normalized_units(item),
        value_type: value_type_name(item["value_type"]),
        status: item_status(item),
        tags: normalize_tags(item["tags"]),
        applications: normalize_tags(item["tags"]).select { |tag| tag[:tag].casecmp("application").zero? }.map { |tag| tag[:value] },
        description: item["description"].presence
      }
    end
  end

  def build_change(item)
    return nil unless numeric_item?(item)

    last_value = item["lastvalue"].to_f
    previous_value = item["prevvalue"].to_f
    delta = last_value - previous_value

    {
      raw: delta,
      display: format_numeric(delta, normalized_units(item), include_sign: true),
      direction: delta.positive? ? "up" : delta.negative? ? "down" : "stable"
    }
  end

  def format_item_value(item, value)
    return nil if value.nil?
    return value.to_s unless numeric_item?(item)

    format_numeric(value.to_f, normalized_units(item))
  end

  def format_numeric(value, units, include_sign: false)
    rounded = value.round(3)
    sign = include_sign && rounded.positive? ? "+" : ""

    return "#{sign}#{rounded}" if units.blank?
    return "#{sign}#{rounded}%" if units == "%"
    return "#{sign}#{rounded}#{units}" if compact_unit?(units)

    "#{sign}#{rounded} #{units}".strip
  end

  def compact_unit?(units)
    units.in?(["ms", "s", "bps", "Bps", "B", "%", "rpm"])
  end

  def normalized_units(item)
    units = item["units"].to_s.strip
    units.presence
  end

  def numeric_item?(item)
    item["value_type"].to_s.in?(%w[0 3])
  end

  def value_type_name(value)
    {
      "0" => "float",
      "1" => "character",
      "2" => "log",
      "3" => "unsigned",
      "4" => "text",
      "5" => "binary"
    }.fetch(value.to_s, "unknown")
  end

  def item_status(item)
    return "unsupported" if item["state"].to_s == "1"
    return "disabled" if item["status"].to_s == "1"

    "active"
  end

  def normalize_tags(tags)
    Array(tags).map do |tag|
      {
        tag: tag["tag"].to_s,
        value: tag["value"].to_s
      }
    end
  end
end
