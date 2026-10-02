require "test_helper"

# REQ-005 (R-2): name race in Executor#persist_map!. Two orderings are simulated without network:
#  - "before the final check": a map with the name is committed after the target was resolved but before
#    persist_map! re-checks the name (build_summary_for runs in between and is the hook);
#  - "at INSERT": the competing row exists when the target map is INSERTed, so the real unique index raises
#    ActiveRecord::RecordNotUnique inside the savepoint. The competitor is inserted right after the final check
#    (outside the savepoint) and the map's own validation is bypassed, because the model's uniqueness
#    validation would otherwise answer first with RecordInvalid; in production that is the narrow window
#    between validation and INSERT.
class Maps::Import::ExecutorNameRaceTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Org Race #{SecureRandom.hex(3)}")
    @name = "Mapa Corrida #{SecureRandom.hex(3)}"
  end

  # ---- (c) ensure_name_still_free! in isolation ----

  test "ensure_name_still_free!: fail policy + new map + existing name raises import_map_name_conflict with id and name" do
    existing = @org.network_maps.create!(name: @name)

    error = assert_raises(Maps::Import::Errors::DomainError) { executor(on_name_conflict: "fail").send(:ensure_name_still_free!, NetworkMap.new) }

    assert_equal "import_map_name_conflict", error.code
    assert_equal({ network_map_id: existing.id, network_map_name: @name }, error.details)
  end

  test "ensure_name_still_free!: does nothing when the name is free, for a persisted map, or with the update policy" do
    assert_nil executor(on_name_conflict: "fail").send(:ensure_name_still_free!, NetworkMap.new)

    existing = @org.network_maps.create!(name: @name)
    assert_nil executor(on_name_conflict: "fail").send(:ensure_name_still_free!, existing)
    assert_nil executor(on_name_conflict: "update").send(:ensure_name_still_free!, NetworkMap.new)
  end

  test "ensure_name_still_free!: only looks inside the executor's organization" do
    other = Organization.create!(name: "Org Race Other #{SecureRandom.hex(3)}")
    other.network_maps.create!(name: @name)

    assert_nil executor(on_name_conflict: "fail").send(:ensure_name_still_free!, NetworkMap.new)
  end

  # ---- (a) fail policy ----

  test "(a) fail: a map created between target resolution and the final check raises import_map_name_conflict, leaving the competitor intact" do
    competitor = nil
    exec = executor(on_name_conflict: "fail")
    exec.define_singleton_method(:build_summary_for) do |*args, **kwargs|
      competitor ||= @organization.network_maps.create!(name: @normalized_payload.dig("map", "name"))
      super(*args, **kwargs)
    end

    error = assert_raises(Maps::Import::Errors::DomainError) { exec.call }

    assert_equal "import_map_name_conflict", error.code
    assert_equal competitor.id, error.details[:network_map_id]
    assert_competitor_untouched(competitor)
    assert_nothing_half_done
  end

  test "(a) fail: a unique violation at INSERT time becomes import_map_name_conflict; competitor intact; nothing half done; outer transaction still usable" do
    ActiveRecord::Base.transaction do
      error = assert_raises(Maps::Import::Errors::DomainError) { race_at_insert(executor(on_name_conflict: "fail")).call }

      assert_equal "import_map_name_conflict", error.code
      assert_equal competitor_map.id, error.details[:network_map_id]
      # The outer transaction must not be aborted by the unique violation (savepoint): querying still works.
      assert_equal 1, NetworkMap.where(organization_id: @org.id, name: @name).count
    end

    assert_competitor_untouched(competitor_map)
    assert_nothing_half_done
  end

  # ---- (b) update policy (default): adopt the existing map and update it ----

  test "(b) update: no spurious import_unique_conflict when the competitor appears before the final check" do
    exec = executor(on_name_conflict: "update")
    exec.define_singleton_method(:build_summary_for) do |*args, **kwargs|
      @organization.network_maps.find_or_create_by!(name: @normalized_payload.dig("map", "name"))
      super(*args, **kwargs)
    end

    outcome = begin
      exec.call
    rescue Maps::Import::Errors::DomainError => e
      e
    end

    refute_equal "import_unique_conflict", outcome.try(:code), "must not surface a spurious unique-constraint error"
  end

  private

  def executor(on_name_conflict:)
    Maps::Import::Executor.new(
      organization: @org,
      normalized_payload: payload(@name),
      mode: "apply",
      on_name_conflict: on_name_conflict
    )
  end

  # Simulates the unique-index race at INSERT time on this executor (see header).
  def race_at_insert(exec)
    exec.define_singleton_method(:ensure_name_still_free!) do |network_map|
      super(network_map)
      next unless network_map.new_record?

      now = Time.current
      NetworkMap.insert_all!([ { organization_id: @organization.id, name: normalized_map_name, created_at: now, updated_at: now } ])
      network_map.define_singleton_method(:valid?) { |*| true }
    end
    exec
  end

  def competitor_map
    NetworkMap.find_by!(organization_id: @org.id, name: @name)
  end

  def assert_competitor_untouched(competitor)
    competitor.reload
    assert_equal 0, competitor.map_nodes.count
    assert_equal 0, competitor.network_cables.count
    assert_nil competitor.metadata["import"]
  end

  def assert_nothing_half_done
    assert_equal 1, NetworkMap.where(organization_id: @org.id).count
    assert_equal 0, MapNode.joins(:network_map).where(network_maps: { organization_id: @org.id }).count
    assert_equal 0, NetworkCable.joins(:network_map).where(network_maps: { organization_id: @org.id }).count
    assert_equal 0, @org.sites.count
  end

  def payload(name)
    {
      "schema_version" => "1.0",
      "provider" => "kmz",
      "coordinate_system" => "geo",
      "map" => { "name" => name, "external_id" => "map-ext-#{SecureRandom.hex(3)}", "metadata" => {} },
      "nodes" => [
        { "external_id" => "node-a", "label" => "Node A", "lat" => -23.50, "lng" => -46.60, "node_kind" => "generic", "metadata" => {} },
        { "external_id" => "node-b", "label" => "Node B", "lat" => -23.51, "lng" => -46.61, "node_kind" => "generic", "metadata" => {} }
      ],
      "cables" => [
        {
          "external_id" => "cable-a", "label" => "Cable A", "source_external_id" => "node-a", "target_external_id" => "node-b",
          "status" => "planned", "cable_type" => "manual", "metadata" => {},
          "points" => [ { "position" => 1, "lat" => -23.505, "lng" => -46.605 }, { "position" => 2, "lat" => -23.507, "lng" => -46.607 } ]
        }
      ]
    }
  end
end
