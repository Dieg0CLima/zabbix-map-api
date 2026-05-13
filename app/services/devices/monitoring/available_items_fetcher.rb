module Devices
  module Monitoring
    # Fetches the catalog of available Zabbix items for a device's monitoring profile.
    #
    # Uses ZabbixHosts::ItemsFetcher internally, which guarantees that every item
    # returned already exists in the local zabbix_items cache (upsert on read).
    # This means the caller can safely use the returned `zabbix_item_id` (local PK)
    # directly in a POST /monitoring/items payload.
    class AvailableItemsFetcher
      DEFAULT_PER_PAGE = 200
      MAX_PER_PAGE     = 750
      MAX_FETCH_LIMIT  = 2_000

      def initialize(profile:, limit: nil, page: nil, per_page: nil, query: nil, force_refresh: false)
        @profile       = profile
        @force_refresh = force_refresh
        @page          = normalize_page(page)
        @per_page      = normalize_per_page(per_page, limit)
        @query         = query.to_s.strip
        @fetch_limit   = MAX_FETCH_LIMIT
      end

      def call
        return empty_result unless profile&.linked?

        raw = ZabbixHosts::ItemsFetcher.new(
          connection:    profile.zabbix_connection,
          hostid:        profile.zabbix_hostid,
          limit:         fetch_limit,
          force_refresh: @force_refresh
        ).call

        items = raw.map { |item| build_item(item) }
        items = filter_items(items)
        paginated_items = paginate_items(items)

        {
          items: paginated_items,
          meta:  meta_payload(items.size, paginated_items.size)
        }
      rescue ZabbixHosts::ItemsFetcher::Error
        empty_result
      end

      private

      attr_reader :profile, :page, :per_page, :query, :fetch_limit

      def normalize_page(value)
        number = value.to_i
        number.positive? ? number : 1
      end

      def normalize_per_page(per_page, limit)
        candidate = per_page.presence || limit
        normalized = candidate.to_i.positive? ? candidate.to_i : DEFAULT_PER_PAGE
        [ normalized, MAX_PER_PAGE ].min
      end

      def empty_result
        {
          items: [],
          meta: {
            hostid: profile&.zabbix_hostid,
            count: 0,
            total_count: 0,
            page: page,
            per_page: per_page,
            total_pages: 0,
            has_next_page: false,
            has_prev_page: page > 1
          }
        }
      end

      def filter_items(items)
        return items if query.blank?

        term = query.downcase
        items.select do |item|
          haystack = [
            item[:label],
            item[:suggested_alias],
            item[:key],
            item[:item_id]
          ].compact.join(" ").downcase
          haystack.include?(term)
        end
      end

      def paginate_items(items)
        offset = (page - 1) * per_page
        return [] if offset >= items.length

        items.slice(offset, per_page) || []
      end

      def meta_payload(total_count, page_count)
        total_pages = total_count.zero? ? 0 : (total_count.to_f / per_page).ceil

        {
          hostid: profile.zabbix_hostid,
          count: page_count,
          total_count: total_count,
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_prev_page: page > 1,
          source: "upserted",
          query: query.presence
        }
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
