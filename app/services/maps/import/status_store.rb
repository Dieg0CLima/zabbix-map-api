module Maps
  module Import
    class StatusStore
      TTL = 24.hours
      FALLBACK_CACHE = ActiveSupport::Cache::MemoryStore.new

      class << self
        def enqueue!(organization:, import_id:, provider:, mode:, requested_by_user_id:, network_map_id: nil)
          write!(
            organization: organization,
            import_id: import_id,
            payload: {
              import_id: import_id,
              status: "queued",
              provider: provider,
              mode: mode,
              requested_by_user_id: requested_by_user_id,
              network_map_id: network_map_id,
              queued_at: Time.current.iso8601
            }
          )
        end

        def running!(organization:, import_id:)
          update!(
            organization: organization,
            import_id: import_id,
            payload: {
              status: "running",
              started_at: Time.current.iso8601
            }
          )
        end

        def completed!(organization:, import_id:, result:)
          update!(
            organization: organization,
            import_id: import_id,
            payload: {
              status: "completed",
              finished_at: Time.current.iso8601,
              summary: result.summary,
              report: result.report,
              warnings: Array(result.respond_to?(:warnings) ? result.warnings : nil),
              network_map_id: result.network_map&.id,
              network_map_name: result.network_map&.name
            }
          )
        end

        def failed!(organization:, import_id:, error_code:, error_message:, details: {})
          update!(
            organization: organization,
            import_id: import_id,
            payload: {
              status: "failed",
              finished_at: Time.current.iso8601,
              error: {
                code: error_code,
                message: error_message,
                details: details
              }
            }
          )
        end

        def fetch(organization:, import_id:)
          cache_backend.read(cache_key(organization_id: organization.id, import_id: import_id))
        end

        private

        def update!(organization:, import_id:, payload:)
          current = fetch(organization: organization, import_id: import_id) || { import_id: import_id }
          write!(
            organization: organization,
            import_id: import_id,
            payload: current.deep_merge(payload)
          )
        end

        def write!(organization:, import_id:, payload:)
          key = cache_key(organization_id: organization.id, import_id: import_id)
          cache_backend.write(key, payload, expires_in: TTL)
          payload
        end

        def cache_key(organization_id:, import_id:)
          "maps:import:status:v1:org:#{organization_id}:import:#{import_id}"
        end

        def cache_backend
          backend = Rails.cache
          return FALLBACK_CACHE if backend.is_a?(ActiveSupport::Cache::NullStore)

          backend
        end
      end
    end
  end
end
