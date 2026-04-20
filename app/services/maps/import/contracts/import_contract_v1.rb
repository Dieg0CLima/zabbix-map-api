module Maps
  module Import
    module Contracts
      class ImportContractV1
        SCHEMA_VERSION = "1.0".freeze
        REQUIRED_ROOT_KEYS = %w[schema_version provider coordinate_system map nodes cables].freeze
        SUPPORTED_COORDINATE_SYSTEMS = %w[geo screen].freeze

        def self.validate!(payload)
          new(payload: payload).validate!
        end

        def initialize(payload:)
          @payload = normalize_payload(payload)
        end

        def validate!
          errors = {}

          unless @payload.is_a?(Hash)
            errors["payload"] = [ "must be an object" ]
            raise_invalid_contract!(errors)
          end

          validate_root(errors)
          validate_map(errors)
          validate_nodes(errors)
          validate_cables(errors)

          raise_invalid_contract!(errors) if errors.any?

          @payload
        end

        private

        def normalize_payload(payload)
          return {} if payload.nil?
          return payload.deep_stringify_keys if payload.respond_to?(:deep_stringify_keys)

          payload
        end

        def validate_root(errors)
          REQUIRED_ROOT_KEYS.each do |key|
            next if present?(@payload[key])

            add_error(errors, key, "is required")
          end

          return if errors.any?

          if @payload["schema_version"].to_s != SCHEMA_VERSION
            add_error(errors, "schema_version", "must be #{SCHEMA_VERSION}")
          end

          unless SUPPORTED_COORDINATE_SYSTEMS.include?(@payload["coordinate_system"].to_s)
            add_error(errors, "coordinate_system", "must be one of: #{SUPPORTED_COORDINATE_SYSTEMS.join(', ')}")
          end
        end

        def validate_map(errors)
          map = @payload["map"]
          unless map.is_a?(Hash)
            add_error(errors, "map", "must be an object")
            return
          end

          add_error(errors, "map.external_id", "is required") unless present?(map["external_id"])
        end

        def validate_nodes(errors)
          nodes = @payload["nodes"]
          unless nodes.is_a?(Array)
            add_error(errors, "nodes", "must be an array")
            return
          end

          nodes.each_with_index do |node, index|
            unless node.is_a?(Hash)
              add_error(errors, "nodes.#{index}", "must be an object")
              next
            end

            add_error(errors, "nodes.#{index}.external_id", "is required") unless present?(node["external_id"])
          end
        end

        def validate_cables(errors)
          cables = @payload["cables"]
          unless cables.is_a?(Array)
            add_error(errors, "cables", "must be an array")
            return
          end

          cables.each_with_index do |cable, index|
            unless cable.is_a?(Hash)
              add_error(errors, "cables.#{index}", "must be an object")
              next
            end

            add_error(errors, "cables.#{index}.external_id", "is required") unless present?(cable["external_id"])
            add_error(errors, "cables.#{index}.source_external_id", "is required") unless present?(cable["source_external_id"])
            add_error(errors, "cables.#{index}.target_external_id", "is required") unless present?(cable["target_external_id"])
          end
        end

        def add_error(errors, key, message)
          errors[key] ||= []
          errors[key] << message
        end

        def present?(value)
          value.respond_to?(:present?) ? value.present? : !value.nil?
        end

        def raise_invalid_contract!(errors)
          raise Maps::Import::Errors::DomainError.new(
            code: "import_contract_invalid",
            message: "Invalid import contract",
            details: { errors: errors, schema_version: SCHEMA_VERSION }
          )
        end
      end
    end
  end
end
