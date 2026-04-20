require "base64"

module Maps
  module Import
    class ApplyJob < ApplicationJob
      queue_as :default

      def perform(organization_id:, import_id:, provider:, input_payload:, network_map_id: nil)
        organization = Organization.find(organization_id)
        network_map = network_map_id.present? ? organization.network_maps.find(network_map_id) : nil
        input = decode_input(input_payload)

        Maps::Import::StatusStore.running!(organization: organization, import_id: import_id)

        result = Maps::Import::Run.new(
          organization: organization,
          provider: provider,
          input: input,
          mode: "apply",
          network_map: network_map,
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
