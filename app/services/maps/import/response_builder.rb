module Maps
  module Import
    class ResponseBuilder
      def initialize(result: nil, import_status: nil, import_id: nil, provider: nil)
        @result = result
        @import_status = import_status
        @import_id = import_id
        @provider = provider
      end

      def preview_payload
        {
          summary: @result.summary,
          report: @result.report,
          normalized_payload: @result.normalized_payload,
          warnings: Array(@result.warnings),
          target_map: {
            action: @result.summary[:map],
            network_map_id: @result.network_map&.id
          }
        }
      end

      def apply_payload
        {
          summary: @result.summary,
          report: @result.report,
          warnings: Array(@result.warnings),
          network_map_id: @result.network_map.id,
          network_map_name: @result.network_map.name
        }
      end

      def queued_payload
        {
          import_id: @import_id,
          status: "queued",
          provider: @provider,
          poll_url: "/api/v1/network_maps/imports/#{@import_id}/status"
        }
      end

      def status_payload
        @import_status
      end
    end
  end
end
