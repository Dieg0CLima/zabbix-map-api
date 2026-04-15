module Devices
  module Monitoring
    class SummaryBuilder
      def initialize(profile:)
        @profile = profile
      end

      def call
        return [] unless profile.present?

        items = profile.device_monitoring_items
                       .includes(:zabbix_item)
                       .select(&method(:relevant?))

        return [] if items.empty?

        live = fetch_live_history(items)

        items.map { |item| build_entry(item, live) }
      end

      private

      attr_reader :profile

      def relevant?(item)
        item.is_primary_metric? || item.is_health_metric?
      end

      def fetch_live_history(items)
        connection = profile.zabbix_connection
        return {} unless connection&.db_enabled?

        loaded = items.select { |i| i.zabbix_item.present? }
        return {} if loaded.empty?

        itemids        = loaded.map { |i| i.zabbix_item.itemid }
        value_type_map = loaded.each_with_object({}) { |i, h| h[i.zabbix_item.itemid.to_s] = i.zabbix_item.value_type.to_s }

        Zabbix::HistoryCache.new(connection: connection, itemids: itemids, value_type_map: value_type_map).fetch
      rescue StandardError
        {}
      end

      def build_entry(item, live)
        zi       = item.zabbix_item
        raw_live = zi && live[zi.itemid.to_s]

        lastvalue = raw_live&.dig("value") || zi&.lastvalue
        lastclock = raw_live&.dig("clock")&.to_s || zi&.lastclock&.to_s

        {
          category:          item.category || item.usage,
          alias:             item.alias || zi&.name,
          usage:             item.usage,
          last_value:        lastvalue,
          display_value:     format_display(lastvalue, zi),
          units:             zi&.units,
          key:               zi&.key_,
          is_primary_metric: item.is_primary_metric?,
          is_health_metric:  item.is_health_metric?,
          last_update:       lastclock,
          data_source:       raw_live ? "live" : "cache"
        }.compact
      end

      def format_display(value, zi)
        return nil unless value && zi

        Zabbix::MetricFormatter.display_value(
          value,
          units:      zi.units,
          value_type: zi.value_type,
          key:        zi.key_
        )
      end
    end
  end
end
