require "test_helper"

class Maps::Import::CanonicalNormalizerTest < ActiveSupport::TestCase
  test "normalizes enums and defaults for nodes and cables" do
    payload = base_payload.merge(
      "nodes" => [
        { "external_id" => " node-a ", "label" => "", "lat" => "-23.5", "lng" => "-46.6", "node_kind" => "SWITCH", "metadata" => "invalid" },
        { "external_id" => "node-b", "label" => "Node B", "lat" => -23.6, "lng" => -46.7, "node_kind" => "invalid_kind" }
      ],
      "cables" => [
        {
          "external_id" => " cable-1 ",
          "source_external_id" => " node-a ",
          "target_external_id" => "node-b",
          "status" => "UP",
          "cable_type" => "FIBER",
          "metadata" => "invalid",
          "points" => [ { "lat" => -23.55, "lng" => -46.65 } ]
        },
        {
          "external_id" => "cable-2",
          "source_external_id" => "node-a",
          "target_external_id" => "node-b",
          "status" => "any_status",
          "cable_type" => "any_type"
        }
      ]
    )

    result = Maps::Import::CanonicalNormalizer.call(payload: payload)

    assert_equal "node-a", result["nodes"][0]["external_id"]
    assert_equal "node-a", result["nodes"][0]["label"]
    assert_equal "switch", result["nodes"][0]["node_kind"]
    assert_equal({}, result["nodes"][0]["metadata"])

    assert_equal "generic", result["nodes"][1]["node_kind"]
    assert_equal "cable-1", result["cables"][0]["external_id"]
    assert_equal "node-a", result["cables"][0]["source_external_id"]
    assert_equal "up", result["cables"][0]["status"]
    assert_equal "fiber", result["cables"][0]["cable_type"]
    assert_equal({}, result["cables"][0]["metadata"])

    assert_equal "planned", result["cables"][1]["status"]
    assert_equal "manual", result["cables"][1]["cable_type"]
  end

  test "raises error when node external_id is duplicated" do
    payload = base_payload.merge(
      "nodes" => [
        { "external_id" => "node-a", "label" => "Node A", "lat" => -23.1, "lng" => -46.1 },
        { "external_id" => "node-a", "label" => "Node A2", "lat" => -23.2, "lng" => -46.2 }
      ]
    )

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::CanonicalNormalizer.call(payload: payload)
    end

    assert_equal "import_payload_invalid", error.code
    assert_includes error.details[:errors].keys, "nodes.external_id"
  end

  test "raises error when cable external_id is duplicated" do
    payload = base_payload.merge(
      "cables" => [
        { "external_id" => "cable-a", "source_external_id" => "node-a", "target_external_id" => "node-b" },
        { "external_id" => "cable-a", "source_external_id" => "node-a", "target_external_id" => "node-b" }
      ]
    )

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::CanonicalNormalizer.call(payload: payload)
    end

    assert_equal "import_payload_invalid", error.code
    assert_includes error.details[:errors].keys, "cables.external_id"
  end

  test "raises error when cable references unknown node external_id" do
    payload = base_payload.merge(
      "cables" => [
        { "external_id" => "cable-a", "source_external_id" => "node-x", "target_external_id" => "node-b" }
      ]
    )

    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::CanonicalNormalizer.call(payload: payload)
    end

    assert_equal "import_payload_invalid", error.code
    assert_includes error.details[:errors].keys, "cables.0.source_external_id"
  end

  test "raises contract error before canonical normalization when root payload is invalid" do
    error = assert_raises(Maps::Import::Errors::DomainError) do
      Maps::Import::CanonicalNormalizer.call(payload: { "provider" => "kmz" })
    end

    assert_equal "import_contract_invalid", error.code
  end

  private

  def base_payload
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
        { "external_id" => "node-a", "label" => "Node A", "lat" => -23.0, "lng" => -46.0 },
        { "external_id" => "node-b", "label" => "Node B", "lat" => -23.1, "lng" => -46.1 }
      ],
      "cables" => [
        { "external_id" => "cable-a", "source_external_id" => "node-a", "target_external_id" => "node-b", "points" => [] }
      ]
    }
  end
end
