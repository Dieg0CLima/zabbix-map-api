module Maps
  module Import
    # Validates and normalizes the optional destination params of a KMZ import:
    # `network_map_name` (name of the map to create) and `on_name_conflict`
    # (`update` | `fail`, only used when no explicit target map is given).
    class DestinationOptions
      MAX_NAME_LENGTH = 255
      CONFLICT_POLICIES = %w[update fail].freeze
      DEFAULT_CONFLICT_POLICY = "update".freeze
      FORBIDDEN_NAME_CHARS = /[[:cntrl:]  ]/

      attr_reader :map_name, :on_name_conflict

      def self.parse(network_map_name:, on_name_conflict:, target_map_given:)
        new(
          map_name: normalize_name(network_map_name),
          on_name_conflict: normalize_policy(on_name_conflict),
          target_map_given: target_map_given
        ).tap(&:validate!)
      end

      def self.normalize_name(value)
        return nil if value.nil?
        raise invalid_name_error unless value.is_a?(String)

        value.strip.presence
      end

      def self.normalize_policy(value)
        return DEFAULT_CONFLICT_POLICY if value.nil?
        raise invalid_option_error unless value.is_a?(String)

        value.strip.presence || DEFAULT_CONFLICT_POLICY
      end

      def self.invalid_name_error
        Maps::Import::Errors::DomainError.new(
          code: "import_invalid_map_name",
          message: "Invalid map name",
          details: { max_length: MAX_NAME_LENGTH }
        )
      end

      def self.invalid_option_error
        Maps::Import::Errors::DomainError.new(
          code: "import_invalid_option",
          message: "Invalid import option",
          details: { param: "on_name_conflict", allowed: CONFLICT_POLICIES }
        )
      end

      def initialize(map_name:, on_name_conflict:, target_map_given:)
        @map_name = map_name
        @on_name_conflict = on_name_conflict
        @target_map_given = target_map_given
      end

      def validate!
        raise self.class.invalid_option_error unless CONFLICT_POLICIES.include?(on_name_conflict)
        raise self.class.invalid_name_error if invalid_name?

        return unless map_name && @target_map_given

        raise Maps::Import::Errors::DomainError.new(
          code: "import_map_name_with_target",
          message: "network_map_name cannot be combined with network_map_id"
        )
      end

      def fail_on_name_conflict?
        on_name_conflict == "fail"
      end

      private

      def invalid_name?
        map_name.present? && (map_name.length > MAX_NAME_LENGTH || map_name.match?(FORBIDDEN_NAME_CHARS))
      end
    end
  end
end
