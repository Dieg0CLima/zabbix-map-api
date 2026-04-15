module Zabbix
  module MetricFormatter
    module_function

    # Returns a human-readable string for a raw Zabbix metric value.
    # @param raw_value [String, nil]
    # @param units [String, nil]
    # @param value_type [String, nil] Zabbix value_type code ("0"=float, "3"=integer, etc.)
    # @param key [String, nil] Zabbix item key (e.g. "system.uptime", "net.if.in[...]")
    def display_value(raw_value, units:, value_type:, key: nil)
      return nil if raw_value.nil?

      return format_uptime(raw_value) if uptime_units?(units) || uptime_key?(key)
      return format_throughput(raw_value) if throughput_units?(units) || throughput_key?(key)

      if numeric_value_type?(value_type)
        stripped = units.to_s.strip
        formatted = format_number(raw_value)
        stripped.present? ? "#{formatted} #{stripped}" : formatted
      else
        raw_value.to_s
      end
    end

    def format_uptime(raw_value)
      seconds = BigDecimal(raw_value.to_s).to_i
      days,    remaining = seconds.divmod(86_400)
      hours,   remaining = remaining.divmod(3_600)
      minutes, remaining = remaining.divmod(60)

      parts = []
      parts << "#{days}d"    if days.positive?
      parts << "#{hours}h"   if hours.positive?
      parts << "#{minutes}m" if minutes.positive?
      parts << "#{remaining}s" if parts.empty? || remaining.positive?
      parts.join(" ")
    rescue ArgumentError, TypeError
      format_number(raw_value)
    end

    def format_throughput(raw_value)
      value = BigDecimal(raw_value.to_s)
      labels = %w[bps Kbps Mbps Gbps Tbps]
      scale = 0
      while value >= 1_000 && scale < labels.size - 1
        value /= 1_000
        scale += 1
      end
      "#{strip_trailing_zeros(value.round(2))} #{labels[scale]}"
    rescue ArgumentError, TypeError
      format_number(raw_value)
    end

    def format_number(raw_value)
      BigDecimal(raw_value.to_s).to_s("F")
    rescue ArgumentError, TypeError
      raw_value.to_s
    end

    def strip_trailing_zeros(value)
      str = value.to_s("F")
      str.include?(".") ? str.sub(/\.?0+\z/, "") : str
    end

    def numeric_value_type?(value_type)
      value_type.to_s.in?(%w[0 3])
    end

    def uptime_units?(units)
      units.to_s.strip.downcase == "uptime"
    end

    def uptime_key?(key)
      key.to_s.include?("system.uptime")
    end

    def throughput_units?(units)
      units.to_s.strip.downcase.include?("bps")
    end

    def throughput_key?(key)
      key.to_s.downcase.include?("net.if")
    end
  end
end
