require "test_helper"

class Maps::Import::RunTest < ActiveSupport::TestCase
  test "orchestrates provider normalization canonicalization and preview execution" do
    organization = Organization.create!(name: "Org Import Run #{SecureRandom.hex(3)}")
    payload = provider_payload(name: "Mapa Run #{SecureRandom.hex(3)}")

    result = Maps::Import::Run.new(
      organization: organization,
      provider: "kmz",
      input: payload,
      mode: "preview"
    ).call

    assert_equal "kmz", result.normalized_payload["provider"]
    assert_equal "created", result.summary[:map]
    assert_equal 2, result.summary.dig(:nodes, :created)
    assert_equal 0, organization.network_maps.count
  end

  test "raises domain error for unsupported provider" do
    organization = Organization.create!(name: "Org Import Run Error #{SecureRandom.hex(3)}")

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::Run.new(
        organization: organization,
        provider: "ozmap",
        input: provider_payload(name: "Mapa X"),
        mode: "preview"
      ).call
    end

    assert_equal "unsupported_import_provider", error.code
  end

  test "adds import observability metadata into report" do
    organization = Organization.create!(name: "Org Import Report #{SecureRandom.hex(3)}")
    payload = provider_payload(name: "Mapa Report #{SecureRandom.hex(3)}")

    result = Maps::Import::Run.new(
      organization: organization,
      provider: "kmz",
      input: payload,
      mode: "preview"
    ).call

    assert result.report[:import_id].present?
    assert result.report[:timings_ms].is_a?(Hash)
    assert result.report.dig(:timings_ms, :parse).is_a?(Numeric)
    assert_equal 0, result.report.dig(:counters, :nodes, :failed)
  end

  test "raises domain error when parse stage exceeds timeout" do
    organization = Organization.create!(name: "Org Import Timeout #{SecureRandom.hex(3)}")
    original_timeout = ENV["IMPORT_PARSE_TIMEOUT_SECONDS"]
    ENV["IMPORT_PARSE_TIMEOUT_SECONDS"] = "0.001"

    slow_adapter_class = Class.new do
      def parse(input:)
        sleep 0.02
        input
      end

      def normalize(parsed:)
        parsed
      end
    end

    error = Maps::Import::ProviderRegistry.stub(:resolve!, slow_adapter_class) do
      assert_raises(Maps::Import::Errors::DomainError) do
        Maps::Import::Run.new(
          organization: organization,
          provider: "kmz",
          input: provider_payload(name: "Mapa Timeout"),
          mode: "preview"
        ).call
      end
    end

    assert_equal "import_parse_timeout", error.code
  ensure
    ENV["IMPORT_PARSE_TIMEOUT_SECONDS"] = original_timeout
  end

  private

  def provider_payload(name:)
    {
      "schema_version" => "1.0",
      "provider" => "kmz",
      "coordinate_system" => "geo",
      "map" => {
        "name" => name,
        "external_id" => "map-ext-#{SecureRandom.hex(3)}",
        "metadata" => {}
      },
      "nodes" => [
        {
          "external_id" => "node-a",
          "label" => "Node A",
          "lat" => -23.50,
          "lng" => -46.60,
          "node_kind" => "switch",
          "metadata" => {}
        },
        {
          "external_id" => "node-b",
          "label" => "Node B",
          "lat" => -23.51,
          "lng" => -46.61,
          "node_kind" => "router",
          "metadata" => {}
        }
      ],
      "cables" => [
        {
          "external_id" => "cable-a",
          "label" => "Cable A",
          "source_external_id" => "node-a",
          "target_external_id" => "node-b",
          "status" => "up",
          "cable_type" => "fiber",
          "metadata" => {},
          "points" => []
        }
      ]
    }
  end
end
