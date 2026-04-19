module Sites
  module Monitoring
    class StatusResolver
      ICMP_STATUS_UP_VALUES = %w[up true ok available reachable online].freeze
      ICMP_STATUS_DOWN_VALUES = %w[down false offline unavailable critical].freeze

      def initialize(metric_items_by_kind:, live_values: {})
        @metric_items_by_kind = metric_items_by_kind || {}
        @live_values = live_values || {}
      end

      def call
        ping_metric = build_metric_payload(metric_items_by_kind[:ping], :ping)
        loss_metric = build_metric_payload(metric_items_by_kind[:loss], :loss)
        response_time_metric = build_metric_payload(metric_items_by_kind[:response_time], :response_time)

        status, reason = resolve_status(ping_metric: ping_metric, loss_metric: loss_metric)
        primary = ping_metric || loss_metric || response_time_metric

        {
          status: status,
          reason: reason,
          source: "zabbix_live_values",
          decision_rule: status_rule_label(reason),
          itemid: primary&.dig(:itemid),
          name: primary&.dig(:name),
          key_: primary&.dig(:key_),
          lastvalue: primary&.dig(:lastvalue),
          lastclock: primary&.dig(:lastclock),
          lastclock_iso: primary&.dig(:lastclock_iso),
          data_source: primary&.dig(:data_source),
          metrics: {
            ping: ping_metric,
            loss: loss_metric,
            response_time: response_time_metric
          }
        }
      end

      private

      attr_reader :metric_items_by_kind, :live_values

      def build_metric_payload(zabbix_item, kind)
        return nil unless zabbix_item

        live = live_values[zabbix_item.itemid.to_s] || {}
        value = live["value"] || zabbix_item.lastvalue
        clock = live["clock"] || zabbix_item.lastclock
        ns = live["ns"]

        {
          metric_kind: kind.to_s,
          id: zabbix_item.id,
          itemid: zabbix_item.itemid.to_s,
          name: zabbix_item.name,
          key_: zabbix_item.key_,
          units: zabbix_item.units,
          value_type: zabbix_item.value_type,
          lastvalue: value&.to_s,
          lastclock: clock&.to_s,
          lastns: ns&.to_s,
          lastclock_iso: clock_to_iso(clock),
          data_source: live.present? ? "live" : "cache"
        }
      end

      def resolve_status(ping_metric:, loss_metric:)
        ping_state = ping_state_from_metric(ping_metric)
        loss_pct = numeric_value(loss_metric&.dig(:lastvalue))

        return [ "down", "ping_down" ] if ping_state == :down
        return [ "down", "loss_100" ] if ping_state == :up && loss_pct && loss_pct >= 100.0
        return [ "up", "ping_up_with_loss" ] if ping_state == :up && loss_pct && loss_pct.positive?
        return [ "up", "ping_up" ] if ping_state == :up

        return [ "down", "loss_100_without_ping" ] if loss_pct && loss_pct >= 100.0

        [ "unknown", "missing_ping" ]
      end

      def ping_state_from_metric(ping_metric)
        return :unknown unless ping_metric

        normalized = ping_metric[:lastvalue].to_s.strip.downcase
        return :unknown if normalized.blank?

        return :up if ICMP_STATUS_UP_VALUES.include?(normalized)
        return :down if ICMP_STATUS_DOWN_VALUES.include?(normalized)

        numeric = numeric_value(normalized)
        return :unknown unless numeric

        numeric.positive? ? :up : :down
      end

      def numeric_value(value)
        return nil if value.blank?

        Float(value.to_s.tr(",", "."))
      rescue ArgumentError, TypeError
        nil
      end

      def status_rule_label(reason)
        case reason
        when "ping_down"
          "icmpping <= 0"
        when "loss_100", "loss_100_without_ping"
          "icmppingloss >= 100%"
        when "ping_up_with_loss"
          "icmpping > 0 com perda"
        when "ping_up"
          "icmpping > 0"
        else
          "sem dados suficientes"
        end
      end

      def clock_to_iso(clock)
        return nil if clock.blank?

        Time.zone.at(clock.to_i).utc.iso8601
      rescue StandardError
        nil
      end
    end
  end
end
