require "base64"

module Maps
  module Import
    class ApplyJob < ApplicationJob
      queue_as :default

      def perform(organization_id:, import_id:, provider:, input_payload:, network_map_id: nil, network_map_name: nil, on_name_conflict: "update")
        organization = Organization.find(organization_id)
        network_map = find_target_map!(organization, network_map_id)
        input = decode_input(input_payload)

        Maps::Import::StatusStore.running!(organization: organization, import_id: import_id)

        result = Maps::Import::Run.new(
          organization: organization,
          provider: provider,
          input: input,
          mode: "apply",
          network_map: network_map,
          network_map_name: network_map_name,
          on_name_conflict: on_name_conflict,
          import_id: import_id
        ).call

        Maps::Import::StatusStore.completed!(
          organization: organization,
          import_id: import_id,
          result: result
        )
      rescue Maps::Import::Errors::DomainError => e
        if organization.present?
          Maps::Import::StatusStore.failed!(
            organization: organization,
            import_id: import_id,
            error_code: e.code,
            error_message: e.message,
            details: e.details
          )
        end
      rescue StandardError => e
        if organization.present?
          Maps::Import::StatusStore.failed!(
            organization: organization,
            import_id: import_id,
            error_code: "import_async_failed",
            error_message: "Async import failed",
            details: { exception: e.class.name, message: e.message }
          )
        end
        raise
      end

      private

      def find_target_map!(organization, network_map_id)
        return nil if network_map_id.blank?

        organization.network_maps.find(network_map_id)
      rescue ActiveRecord::RecordNotFound
        raise Maps::Import::Errors::DomainError.new(
          code: "import_target_map_not_found",
          message: "Target map not found"
        )
      end

      def decode_input(payload)
        source = payload.is_a?(Hash) ? payload.deep_symbolize_keys : {}
        kind = source[:kind].to_s
        data = source[:data].to_s

        case kind
        when "binary"
          Base64.decode64(data)
        else
          data
        end
      end
    end
  end
end
