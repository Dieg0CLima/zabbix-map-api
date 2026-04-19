module Sites
  module Monitoring
    module PingItemMatcher
      extend self

      ICMP_PING_KEY_PATTERN = /\A(?:icmpping|fping)(?:\[|\z)/i.freeze
      ICMP_LOSS_KEY_PATTERN = /\Aicmppingloss(?:\[|\z)/i.freeze
      ICMP_RESPONSE_TIME_KEY_PATTERN = /\Aicmppingsec(?:\[|\z)/i.freeze
      ICMP_PING_NAME_PATTERN = /icmp\s*ping/i.freeze
      ICMP_LOSS_NAME_PATTERN = /icmp\s*loss/i.freeze
      ICMP_RESPONSE_TIME_NAME_PATTERN = /icmp.*(?:response|latency|tempo|time)|response\s*time/i.freeze

      METRIC_KIND_PRIORITY = {
        ping: 0,
        loss: 1,
        response_time: 2
      }.freeze

      def icmp_metric_kind(zabbix_item)
        return nil unless zabbix_item

        key = zabbix_item.key_.to_s
        name = zabbix_item.name.to_s

        return :loss if key.match?(ICMP_LOSS_KEY_PATTERN) || name.match?(ICMP_LOSS_NAME_PATTERN)
        return :response_time if key.match?(ICMP_RESPONSE_TIME_KEY_PATTERN) || name.match?(ICMP_RESPONSE_TIME_NAME_PATTERN)
        return :ping if key.match?(ICMP_PING_KEY_PATTERN) || name.match?(ICMP_PING_NAME_PATTERN)

        nil
      end

      def icmp_metric_item?(zabbix_item)
        icmp_metric_kind(zabbix_item).present?
      end

      def icmp_ping_item?(zabbix_item)
        icmp_metric_item?(zabbix_item)
      end
    end
  end
end
