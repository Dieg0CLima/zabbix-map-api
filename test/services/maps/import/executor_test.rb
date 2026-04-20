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

  test "apply imports sites and pops from node metadata and binds map nodes" do
    organization = Organization.create!(name: "Org Import Site Pop #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa Site Pop #{SecureRandom.hex(3)}")
    payload["nodes"][0]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "site-a",
      "site_name" => "Site A"
    }
    payload["nodes"][1]["metadata"] = {
      "import_entity" => "pop",
      "site_external_id" => "site-b",
      "site_name" => "Site B",
      "pop_external_id" => "pop-b",
      "pop_name" => "POP B"
    }

    result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: payload,
      mode: "apply"
    ).call

    map = result.network_map
    site_a = organization.sites.find_by!(external_id: "site-a")
    site_b = organization.sites.find_by!(external_id: "site-b")
    pop_b = map.map_pops.find_by!(external_id: "pop-b")
    node_a = map.map_nodes.find_by!(external_id: "node-a")
    node_b = map.map_nodes.find_by!(external_id: "node-b")

    assert_equal "Site A", site_a.name
    assert_equal "Site B", site_b.name
    assert_equal site_b.id, pop_b.site_id
    assert_equal "Site", node_a.mappable_type
    assert_equal site_a.id, node_a.mappable_id
    assert_equal "Site", node_b.mappable_type
    assert_equal site_b.id, node_b.mappable_id
    assert_equal pop_b.id, node_b.map_pop_id
  end

  test "apply reuses existing site with same name to avoid unique violation on organization name index" do
    organization = Organization.create!(name: "Org Import Existing Site #{SecureRandom.hex(3)}")
    existing_site = organization.sites.create!(
      external_id: "existing-site-ext",
      name: "Caixa de Abordagem Equinix SP4",
      slug: "caixa-de-abordagem-equinix-sp4"
    )

    payload = normalized_payload(name: "Mapa Existing Site #{SecureRandom.hex(3)}")
    payload["nodes"][0]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "kmz-site-new-ext",
      "site_name" => "Caixa de Abordagem Equinix SP4"
    }

    result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: payload,
      mode: "apply"
    ).call

    map = result.network_map
    node_a = map.map_nodes.find_by!(external_id: "node-a")

    assert_equal 1, organization.sites.where(name: "Caixa de Abordagem Equinix SP4").count
    assert_equal existing_site.id, node_a.mappable_id
    assert_equal "Site", node_a.mappable_type
  end

  test "apply deduplicates site creation by name within the same payload batch" do
    organization = Organization.create!(name: "Org Import Duplicate Name Batch #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa Duplicate Name Batch #{SecureRandom.hex(3)}")
    payload["nodes"][0]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "kmz-site-a",
      "site_name" => "Caixa de Abordagem Equinix SP4"
    }
    payload["nodes"][1]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "kmz-site-b",
      "site_name" => "Caixa de Abordagem Equinix SP4"
    }

    result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: payload,
      mode: "apply"
    ).call

    map = result.network_map
    node_a = map.map_nodes.find_by!(external_id: "node-a")
    node_b = map.map_nodes.find_by!(external_id: "node-b")
    site = organization.sites.find_by!(name: "Caixa de Abordagem Equinix SP4")

    assert_equal 1, organization.sites.where(name: "Caixa de Abordagem Equinix SP4").count
    assert_equal site.id, node_a.mappable_id
    assert_equal site.id, node_b.mappable_id
  end

  test "apply does not raise when generated_endpoint shares site_external_id with existing node" do
    organization = Organization.create!(name: "Org Import GenEndpoint #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa GenEndpoint #{SecureRandom.hex(3)}")
    payload["nodes"][0]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "site-a",
      "site_name" => "Site A"
    }
    payload["nodes"][1]["metadata"] = {
      "generated_endpoint" => true,
      "site_external_id" => "site-a"
    }

    result = assert_nothing_raised do
      Maps::Import::Executor.new(
        organization: organization,
        normalized_payload: payload,
        mode: "apply"
      ).call
    end

    map = result.network_map
    node_a = map.map_nodes.find_by!(external_id: "node-a")
    node_b = map.map_nodes.find_by!(external_id: "node-b")

    assert_equal "Site", node_a.mappable_type
    assert_nil node_b.mappable_id, "generated_endpoint node must not claim the site as mappable"
    assert_equal 1, organization.sites.where(name: "Site A").count
  end

  test "apply does not raise when two non-endpoint nodes alias to the same site via name deduplication" do
    organization = Organization.create!(name: "Org Import SiteAlias #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa SiteAlias #{SecureRandom.hex(3)}")
    # Both nodes have the same site_name → site_index maps both to the same Site record
    payload["nodes"][0]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "node-a",
      "site_name" => "Site Compartilhada"
    }
    payload["nodes"][1]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "node-b",
      "site_name" => "Site Compartilhada"
    }

    result = assert_nothing_raised do
      Maps::Import::Executor.new(
        organization: organization,
        normalized_payload: payload,
        mode: "apply"
      ).call
    end

    map = result.network_map
    node_a = map.map_nodes.find_by!(external_id: "node-a")
    node_b = map.map_nodes.find_by!(external_id: "node-b")

    assert_equal 1, organization.sites.where(name: "Site Compartilhada").count
    # Exactly one node holds the site; the other gets nil mappable
    mapped_nodes = [node_a, node_b].select { |n| n.mappable_type == "Site" }
    assert_equal 1, mapped_nodes.size, "exactly one node should claim the shared site"
  end

  test "apply sanitizes equivalent site names and deduplicates batch mapping" do
    organization = Organization.create!(name: "Org Import Name Sanitization #{SecureRandom.hex(3)}")
    payload = normalized_payload(name: "Mapa Name Sanitization #{SecureRandom.hex(3)}")
    payload["nodes"][0]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "kmz-site-1",
      "site_name" => "  Caixa   de   Abordagem   Equinix   SP4  "
    }
    payload["nodes"][1]["metadata"] = {
      "import_entity" => "site",
      "site_external_id" => "kmz-site-2",
      "site_name" => "Caixa de Abordagem Equinix SP4"
    }

    result = Maps::Import::Executor.new(
      organization: organization,
      normalized_payload: payload,
      mode: "apply"
    ).call

    map = result.network_map
    node_a = map.map_nodes.find_by!(external_id: "node-a")
    node_b = map.map_nodes.find_by!(external_id: "node-b")

    assert_equal 1, organization.sites.where(name: "Caixa de Abordagem Equinix SP4").count
    assert_equal node_a.mappable_id, node_b.mappable_id
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
