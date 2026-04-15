module Devices
  module Monitoring
    # Fetches the catalog of available Zabbix items for a device's monitoring profile.
    #
    # Uses ZabbixHosts::ItemsFetcher internally, which guarantees that every item
    # returned already exists in the local zabbix_items cache (upsert on read).
    # This means the caller can safely use the returned `zabbix_item_id` (local PK)
    # directly in a POST /monitoring/items payload.
    class AvailableItemsFetcher
      DEFAULT_LIMIT = 200
      MAX_LIMIT     = 750

      def initialize(profile:, limit: nil, force_refresh: false)
        @profile       = profile
        @force_refresh = force_refresh
        normalized = limit.to_i.positive? ? limit.to_i : DEFAULT_LIMIT
        @limit = [normalized, MAX_LIMIT].min
      end

      def call
        return empty_result unless profile&.linked?

        raw = ZabbixHosts::ItemsFetcher.new(
          connection:    profile.zabbix_connection,
          hostid:        profile.zabbix_hostid,
          limit:         limit,
          force_refresh: @force_refresh
        ).call

        items = raw.map { |item| build_item(item) }

        {
          items: items,
          meta:  { hostid: profile.zabbix_hostid, count: items.size, source: "upserted" }
        }
      rescue ZabbixHosts::ItemsFetcher::Error
        empty_result
      end

      private

      attr_reader :profile, :limit

      def empty_result
        { items: [], meta: { hostid: profile&.zabbix_hostid, count: 0 } }
      end

      def build_item(item)
        hint = Devices::Monitoring::ClassificationHintResolver.for(
          key:   item[:key],
          name:  item[:name],
          units: item[:units]
        )

        {
          item_id:       item[:itemid],
          zabbix_item_id: item[:value],   # local PK — safe to POST directly
          label:          item[:name],
          key:            item[:key],
          units:          item[:units],
          value_type:     item[:value_type],
          category_hint:  hint&.dig(:category),
          suggested_alias: item[:name],
          map_visibility: hint&.dig(:map_visibility),
          metadata:       {}
        }
      end
    end
  end
end
