module Devices
  module Monitoring
    class ClassificationHintResolver
      HINTS = [
        {
          category: "cpu",
          match: ->(attrs) { attrs[:key]&.match?(%r{system\.cpu}) || attrs[:name]&.downcase&.include?("cpu") },
          usage: "map",
          priority: 100,
          map_visibility: true,
          primary: true,
          health: true
        },
        {
          category: "memory",
          match: ->(attrs) { attrs[:key]&.match?(%r{vm\.memory}) || attrs[:name]&.downcase&.include?("memory") },
          usage: "map",
          priority: 90,
          map_visibility: true,
          primary: true
        },
        {
          category: "interface_traffic_in",
          match: ->(attrs) { attrs[:key]&.match?(%r{net\.if\.in}) },
          usage: "indicators",
          priority: 80
        },
        {
          category: "interface_traffic_out",
          match: ->(attrs) { attrs[:key]&.match?(%r{net\.if\.out}) },
          usage: "indicators",
          priority: 80
        },
        {
          category: "interface_status",
          match: ->(attrs) {
            attrs[:key]&.match?(%r{net\.if\.status|ifOperStatus}) ||
              attrs[:name]&.downcase&.match?(/operational status|interface status|link status/)
          },
          usage: "health",
          priority: 85,
          health: true,
          map_visibility: true
        },
        {
          category: "interface_errors",
          match: ->(attrs) { attrs[:key]&.downcase&.include?("errors") || attrs[:name]&.downcase&.include?("errors") },
          usage: "health",
          priority: 70,
          health: true
        },
        {
          category: "interface_discards",
          match: ->(attrs) { attrs[:key]&.downcase&.include?("discards") || attrs[:name]&.downcase&.include?("discard") },
          usage: "health",
          priority: 70,
          health: true
        },
        {
          category: "temperature",
          match: ->(attrs) { attrs[:units]&.downcase&.include?("c") || attrs[:key]&.include?("temp") },
          usage: "observability",
          priority: 60,
          health: true
        },
        {
          category: "uptime",
          match: ->(attrs) { attrs[:key]&.include?("uptime") || attrs[:name]&.downcase&.include?("uptime") },
          usage: "health",
          priority: 60,
          health: true
        }
      ].freeze

      def self.for(item_attrs)
        new(item_attrs).hint
      end

      def initialize(item_attrs)
        @attrs = item_attrs.deep_symbolize_keys
      end

      def hint
        HINTS.find { |hint| hint[:match].call(@attrs) }
      end
    end
  end
end
