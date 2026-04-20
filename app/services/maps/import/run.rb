require "securerandom"
require "timeout"

module Maps
  module Import
    class Run
      Result = Struct.new(:network_map, :summary, :report, :normalized_payload, keyword_init: true)

      def initialize(organization:, provider:, input:, mode:, network_map: nil, import_id: nil)
        @organization = organization
        @provider = provider
        @input = input
        @mode = mode
        @network_map = network_map
        @import_id = import_id.presence || SecureRandom.uuid
      end

      def call
        durations = {}
        log_event("import.started", mode: @mode, provider: @provider, organization_id: @organization.id)

        adapter_class = with_timing(durations, :resolve_provider) { Maps::Import::ProviderRegistry.resolve!(@provider) }
        adapter = adapter_class.new
        parsed = with_timing(durations, :parse) { parse_with_timeout(adapter) }
        provider_payload = with_timing(durations, :provider_normalize) { adapter.normalize(parsed: parsed) }
        normalized_payload = with_timing(durations, :canonical_normalize) { Maps::Import::CanonicalNormalizer.call(payload: provider_payload) }

        execution = with_timing(durations, :execute) do
          Maps::Import::Executor.new(
            organization: @organization,
            normalized_payload: normalized_payload,
            mode: @mode,
            network_map: @network_map
          ).call
        end

        report = execution.report.merge(
          import_id: @import_id,
          timings_ms: durations,
          counters: counters_from_summary(execution.summary)
        )

        log_event("import.completed", mode: @mode, provider: @provider, timings_ms: durations, summary: execution.summary)

        Result.new(network_map: execution.network_map, summary: execution.summary, report: report, normalized_payload: normalized_payload)
      rescue Maps::Import::Errors::DomainError => e
        log_event("import.failed", mode: @mode, provider: @provider, error_code: e.code, error_message: e.message)
        raise
      end

      private

      def parse_with_timeout(adapter)
        Timeout.timeout(parse_timeout_seconds) do
          adapter.parse(input: @input)
        end
      rescue Timeout::Error
        raise Maps::Import::Errors::DomainError.new(
          code: "import_parse_timeout",
          message: "Import parsing exceeded timeout",
          details: { timeout_seconds: parse_timeout_seconds }
        )
      end

      def parse_timeout_seconds
        configured = ENV["IMPORT_PARSE_TIMEOUT_SECONDS"].to_f
        configured.positive? ? configured : 15.0
      end

      def with_timing(durations, key)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        durations[key] = (elapsed * 1000.0).round(2)
        result
      end

      def counters_from_summary(summary)
        {
          nodes: {
            created: summary.dig(:nodes, :created).to_i,
            updated: summary.dig(:nodes, :updated).to_i,
            skipped: 0,
            failed: 0
          },
          cables: {
            created: summary.dig(:cables, :created).to_i,
            updated: summary.dig(:cables, :updated).to_i,
            skipped: 0,
            failed: 0
          }
        }
      end

      def log_event(event, payload = {})
        Rails.logger.info(
          {
            event: event,
            import_id: @import_id,
            provider: @provider,
            mode: @mode
          }.merge(payload).to_json
        )
      end
    end
  end
end
