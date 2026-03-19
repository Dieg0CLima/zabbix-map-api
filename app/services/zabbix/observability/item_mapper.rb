class Zabbix::Observability::ItemMapper
  TRAFFIC_IN_PATTERNS = [/\Anet\.if\.in/i, /ifin(?:octets|errors|util)?/i, /inbound/i].freeze
  TRAFFIC_OUT_PATTERNS = [/\Anet\.if\.out/i, /ifout(?:octets|errors|util)?/i, /outbound/i].freeze
  CPU_PATTERNS = [/system\.cpu\.util/i, /cpu utilization/i, /cpu usage/i].freeze
  MEMORY_PATTERNS = [/vm\.memory\.size\[pused\]/i, /memory utilization/i, /memory usage/i].freeze

  def initialize(items)
    @items = Array(items)
  end

  def traffic_items
    @items.filter_map do |item|
      direction = classify_direction(item)
      next unless direction

      interface_name = extract_interface_name(item)
      next if interface_name.blank?

      item.merge("__direction" => direction, "__interface_name" => interface_name)
    end
  end

  def cpu_item
    find_first(CPU_PATTERNS)
  end

  def memory_item
    find_first(MEMORY_PATTERNS)
  end

  private

  def find_first(patterns)
    @items.find { |item| matches_any?(item, patterns) }
  end

  def classify_direction(item)
    return :in if matches_any?(item, TRAFFIC_IN_PATTERNS)
    return :out if matches_any?(item, TRAFFIC_OUT_PATTERNS)

    nil
  end

  def extract_interface_name(item)
    key = item["key_"].to_s
    if (match = key.match(/\[(?:if(?:In|Out)Octets\.)?([^,\]]+)/i))
      return match[1].to_s.tr('"', "")
    end

    name = item["name"].to_s
    if (match = name.match(/(?:Interface|net|traffic|bits|octets)[^\w-]*([[:alnum:]_\/.:-]+)/i))
      return match[1]
    end

    item.dig("tags", 0, "value")
  end

  def matches_any?(item, patterns)
    patterns.any? { |pattern| item["key_"].to_s.match?(pattern) || item["name"].to_s.match?(pattern) }
  end
end
