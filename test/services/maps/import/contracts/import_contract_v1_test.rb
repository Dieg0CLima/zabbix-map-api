require "test_helper"

class Maps::Import::Contracts::ImportContractV1Test < ActiveSupport::TestCase
  test "validates and returns normalized payload for valid contract" do
    payload = valid_payload.deep_symbolize_keys

    result = Maps::Import::Contracts::ImportContractV1.validate!(payload)

    assert_equal "1.0", result["schema_version"]
    assert_equal "kmz", result["provider"]
    assert_equal "geo", result["coordinate_system"]
    assert_equal "map-ext-1", result.dig("map", "external_id")
  end

  test "raises domain error when required root keys are missing" do
    payload = { provider: "kmz" }

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::Contracts::ImportContractV1.validate!(payload)
    end

    assert_equal "import_contract_invalid", error.code
    assert_includes error.details[:errors].keys, "schema_version"
    assert_includes error.details[:errors].keys, "map"
    assert_includes error.details[:errors].keys, "nodes"
    assert_includes error.details[:errors].keys, "cables"
  end

  test "raises domain error when map and entities miss external_id" do
    payload = valid_payload.merge(
      "map" => { "name" => "Sem External Id" },
      "nodes" => [ { "label" => "Node sem id" } ],
      "cables" => [ { "label" => "Cable sem id", "source_external_id" => "node-a", "target_external_id" => "node-b" } ]
    )

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::Contracts::ImportContractV1.validate!(payload)
    end

    assert_equal "import_contract_invalid", error.code
    assert_includes error.details[:errors].keys, "map.external_id"
    assert_includes error.details[:errors].keys, "nodes.0.external_id"
    assert_includes error.details[:errors].keys, "cables.0.external_id"
  end

  test "raises domain error when cable references are missing" do
    payload = valid_payload.merge(
      "cables" => [ { "external_id" => "cable-a" } ]
    )

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::Contracts::ImportContractV1.validate!(payload)
    end

    assert_equal "import_contract_invalid", error.code
    assert_includes error.details[:errors].keys, "cables.0.source_external_id"
    assert_includes error.details[:errors].keys, "cables.0.target_external_id"
  end

  private

  def valid_payload
    {
      "schema_version" => "1.0",
      "provider" => "kmz",
      "coordinate_system" => "geo",
      "map" => {
        "name" => "Mapa Teste",
        "external_id" => "map-ext-1",
        "metadata" => {}
      },
      "nodes" => [
        {
          "external_id" => "node-a",
          "label" => "Node A",
          "lat" => -23.0,
          "lng" => -46.0
        }
      ],
      "cables" => [
        {
          "external_id" => "cable-a",
          "label" => "Cable A",
          "source_external_id" => "node-a",
          "target_external_id" => "node-b",
          "points" => []
        }
      ]
    }
  end
end
