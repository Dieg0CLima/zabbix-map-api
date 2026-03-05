require "test_helper"

class Api::V1::NetworkCablesFilterTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "filter-test@example.com", password: "Password!123", password_confirmation: "Password!123")
    @organization = Organization.create!(name: "Org Cable Filter")
    Membership.create!(user: @user, organization: @organization, role: "admin")

    @network_map = @organization.network_maps.create!(name: "Map Filter", source_type: "manual")
    @pop = @network_map.map_pops.create!(name: "POP A", external_id: "pop-a", lat: -23.1, lng: -46.1, color: "#7c3aed")

    @cable_active = create_cable("cable-active", status: "active", cable_type: "feeder", label: "Backbone")
    @cable_planned = create_cable("cable-planned", status: "planned", cable_type: "distribution", label: "Access")

    sign_in_user
  end

  test "filters cables by status" do
    get cables_url(status: "active"), as: :json
    assert_response :ok

    ids = extract_external_ids
    assert_includes ids, "cable-active"
    refute_includes ids, "cable-planned"
  end

  test "filters cables by cable_type" do
    get cables_url(cable_type: "distribution"), as: :json
    assert_response :ok

    ids = extract_external_ids
    assert_includes ids, "cable-planned"
    refute_includes ids, "cable-active"
  end

  test "filters cables by search query" do
    get cables_url(q: "Backbone"), as: :json
    assert_response :ok

    ids = extract_external_ids
    assert_includes ids, "cable-active"
    refute_includes ids, "cable-planned"
  end

  test "returns all cables without filters" do
    get cables_url, as: :json
    assert_response :ok

    assert_equal 2, response.parsed_body["data"].size
  end

  private

  def cables_url(**filter_params)
    base = "/api/v1/network_maps/#{@network_map.id}/network_cables"
    return base if filter_params.empty?

    "#{base}?#{filter_params.to_query}"
  end

  def sign_in_user
    post "/api/v1/users/sign_in", params: {
      user: { email: @user.email, password: "Password!123", organization_id: @organization.id }
    }, as: :json

    @auth_token = response.headers["Authorization"]
  end

  def get(url, **options)
    options[:headers] ||= {}
    options[:headers]["Authorization"] = @auth_token if @auth_token
    super(url, **options)
  end

  def extract_external_ids
    response.parsed_body["data"].map { |c| c["external_id"] }
  end

  def create_cable(external_id, status:, cable_type:, label:)
    cable = @network_map.network_cables.create!(
      external_id:, status:, cable_type:, label:,
      source_pop: @pop,
      color: "#0891b2", weight: 4, pattern: "solid"
    )

    cable.network_cable_points.create!(position: 0, x: -23.1, y: -46.1)
    cable.network_cable_points.create!(position: 1, x: -23.2, y: -46.2)

    cable
  end
end
