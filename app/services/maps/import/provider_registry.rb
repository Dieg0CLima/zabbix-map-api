module Maps
  module Import
    class ProviderRegistry
      PROVIDERS = {
        "kmz" => Maps::Import::Providers::KmzAdapter
      }.freeze

      def self.resolve!(provider_key)
        key = provider_key.to_s.strip.downcase
        provider = PROVIDERS[key]
        return provider if provider

        raise Maps::Import::Errors::DomainError.new(
          code: "unsupported_import_provider",
          message: "Unsupported import provider",
          details: {
            provider: key,
            supported_providers: PROVIDERS.keys
          }
        )
      end
    end
  end
end
