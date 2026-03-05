require "test_helper"

class NetworkCables::FilterQueryTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Org Filter Test")
    @network_map = @organization.network_maps.create!(name: "Map Filter", source_type: "manual")

    @pop_a = @network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.1, lng: -46.1, color: "#7c3aed")
    @pop_b = @network_map.map_pops.create!(name: "POP B", external_id: "pop-b", lat: -23.2, lng: -46.2, color: "#7c3aed")

    @cable_active = create_cable(
      external_id: "cable-1", status: "active", cable_type: "feeder", label: "Link Principal",
      source_pop: @pop_a, target_pop: @pop_b,
      metadata: { "network_role" => "backbone", "fiber_count" => 12, "code" => "FO-001" }
    )

    @cable_planned = create_cable(
      external_id: "cable-2", status: "planned", cable_type: "distribution", label: "Link Secundario",
      source_pop: @pop_a,
      metadata: { "network_role" => "access", "fiber_count" => 6 }
    )
  end

  test "filters by status" do
    result = apply_filter(status: "active")
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "filters by cable_type" do
    result = apply_filter(cable_type: "distribution")
    assert_includes result, @cable_planned
    refute_includes result, @cable_active
  end

  test "filters by network_role from metadata" do
    result = apply_filter(network_role: "backbone")
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "filters by source_pop_id using external_id" do
    result = apply_filter(source_pop_id: "pop-a")
    assert_includes result, @cable_active
    assert_includes result, @cable_planned
  end

  test "filters by target_pop_id using numeric id" do
    result = apply_filter(target_pop_id: @pop_b.id.to_s)
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "filters by search query on label" do
    result = apply_filter(q: "Principal")
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "filters by search query on metadata code" do
    result = apply_filter(q: "FO-001")
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "filters by fiber_count_min" do
    result = apply_filter(fiber_count_min: "10")
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "filters by fiber_count_max" do
    result = apply_filter(fiber_count_max: "8")
    assert_includes result, @cable_planned
    refute_includes result, @cable_active
  end

  test "combines multiple filters" do
    result = apply_filter(status: "active", cable_type: "feeder")
    assert_includes result, @cable_active
    refute_includes result, @cable_planned
  end

  test "returns all when no filters applied" do
    result = apply_filter({})
    assert_equal 2, result.size
  end

  private

  def apply_filter(filter_params)
    NetworkCables::FilterQuery.new(
      scope: @network_map.network_cables,
      params: ActionController::Parameters.new(filter_params).permit!,
      network_map: @network_map
    ).call.to_a
  end

  def create_cable(external_id:, status:, cable_type:, label:, source_pop:, target_pop: nil, metadata: {})
    cable = @network_map.network_cables.create!(
      external_id:, status:, cable_type:, label:,
      source_pop:, target_pop:,
      color: "#0891b2", weight: 4, pattern: "solid",
      metadata:
    )

    cable.network_cable_points.create!(position: 0, x: -23.1, y: -46.1)
    cable.network_cable_points.create!(position: 1, x: -23.2, y: -46.2)

    cable
  end
end
