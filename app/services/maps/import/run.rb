module Maps
  module Import
    class Run
      Result = Struct.new(:network_map, :summary, :report, :normalized_payload, keyword_init: true)

      def initialize(organization:, provider:, input:, mode:, network_map: nil)
        @organization = organization
        @provider = provider
        @input = input
        @mode = mode
        @network_map = network_map
      end

      def call
        adapter_class = Maps::Import::ProviderRegistry.resolve!(@provider)
        adapter = adapter_class.new

        parsed = adapter.parse(input: @input)
        provider_payload = adapter.normalize(parsed: parsed)
        normalized_payload = Maps::Import::CanonicalNormalizer.call(payload: provider_payload)

        execution = Maps::Import::Executor.new(
          organization: @organization,
          normalized_payload: normalized_payload,
          mode: @mode,
          network_map: @network_map
        ).call

        Result.new(
          network_map: execution.network_map,
          summary: execution.summary,
          report: execution.report,
          normalized_payload: normalized_payload
        )
      end
    end
  end
end
