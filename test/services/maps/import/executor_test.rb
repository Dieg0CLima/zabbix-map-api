require "test_helper"

class Maps::Import::ExecutorTest < ActiveSupport::TestCase
  test "preview does not persist and returns summary" do
    organization = Organization.create!(name: "Org Import Preview #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa Preview #{SecureRandom.hex(3)}")

    result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: payload,
      mode: "preview"
    ).call

    assert_equal "created", result.summary[:map]
    assert_equal 2, result.summary.dig(:nodes, :created)
    assert_equal 1, result.summary.dig(:cables, :created)
    assert_equal 0, organization.network_maps.count
  end

  test "apply creates map nodes cables and points" do
    organization = Organization.create!(name: "Org Import Apply #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa Apply #{SecureRandom.hex(3)}")

    result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: payload,
      mode: "apply"
    ).call

    map = result.network_map
    assert map.persisted?
    assert_equal 1, organization.network_maps.count
    assert_equal 2, map.map_nodes.count
    assert_equal 1, map.network_cables.count
    assert_equal 2, map.network_cables.first.network_cable_points.count
  end

  test "apply is idempotent and updates existing records by external_id" do
    organization = Organization.create!(name: "Org Import Idempotent #{SecureRandom.hex(3)}")
    map_name = "Mapa Idempotente #{SecureRandom.hex(3)}"

    first_payload = normalized_payload(name: map_name, node_a_label: "Node A")
    second_payload = normalized_payload(name: map_name, node_a_label: "Node A Atualizado")

    first_result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: first_payload,
      mode: "apply"
    ).call

    second_result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: second_payload,
      mode: "apply"
    ).call

    map = second_result.network_map

    assert_equal first_result.network_map.id, map.id
    assert_equal 1, organization.network_maps.count
    assert_equal 2, map.map_nodes.count
    assert_equal 1, map.network_cables.count
    assert_equal "Node A Atualizado", map.map_nodes.find_by!(external_id: "node-a").label
  end

  private

  def normalized_payload(name:, node_a_label: "Node A")
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
          "label" => node_a_label,
          "lat" => -23.50,
          "lng" => -46.60,
          "node_kind" => "generic",
          "metadata" => {}
        },
        {
          "external_id" => "node-b",
          "label" => "Node B",
          "lat" => -23.51,
          "lng" => -46.61,
          "node_kind" => "generic",
          "metadata" => {}
        }
      ],
      "cables" => [
        {
          "external_id" => "cable-a",
          "label" => "Cable A",
          "source_external_id" => "node-a",
          "target_external_id" => "node-b",
          "status" => "planned",
          "cable_type" => "manual",
          "metadata" => {},
          "points" => [
            { "position" => 1, "lat" => -23.505, "lng" => -46.605 },
            { "position" => 2, "lat" => -23.507, "lng" => -46.607 }
          ]
        }
      ]
    }
  end
end
