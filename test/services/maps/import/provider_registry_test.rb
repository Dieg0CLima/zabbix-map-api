require "test_helper"

class Maps::Import::ProviderRegistryTest < ActiveSupport::TestCase
  test "resolves kmz provider" do
    provider = Maps::Import::ProviderRegistry.resolve!("kmz")

    assert_equal Maps::Import::Providers::KmzAdapter, provider
  end

  test "resolves provider case-insensitively" do
    provider = Maps::Import::ProviderRegistry.resolve!("KMZ")

    assert_equal Maps::Import::Providers::KmzAdapter, provider
  end

  test "raises domain error for unsupported provider" do
    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::ProviderRegistry.resolve!("ozmap")
    end

    assert_equal "unsupported_import_provider", error.code
    assert_equal "ozmap", error.details[:provider]
    assert_includes error.details[:supported_providers], "kmz"
  end
end
