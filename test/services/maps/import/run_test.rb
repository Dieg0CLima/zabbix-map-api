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
