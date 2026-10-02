require "test_helper"

# REQ-002 characterization of MapChannel (current behavior on Rails 8.0.x). Describes what exists today,
# including doubtful behavior (see REQ-002 O2/O3); nothing here is a recommendation.
class MapChannelTest < ActionCable::Channel::TestCase
  tests MapChannel

  def create_user(label, admin: false)
    User.create!(email: "#{label}.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123", admin: admin)
  end

  def create_org_with_map(label)
    org = Organization.create!(name: "Org #{label} #{SecureRandom.hex(3)}")
    map = org.network_maps.create!(name: "Map #{label} #{SecureRandom.hex(3)}")
    [ org, map ]
  end

  def member_of(org, label, role: "viewer")
    user = create_user(label)
    org.memberships.create!(user: user, role: role)
    user
  end

  def last_message
    transmissions.last
  end

  test "CA13: member of the organization subscribes to its map: confirmed, streams the map, transmits initial payload" do
    org, map = create_org_with_map("a13")
    user = member_of(org, "a13")
    stub_connection current_user: user

    subscribe organization_id: org.id, map_id: map.id

    assert subscription.confirmed?
    assert_has_stream_for map
    assert_equal 1, transmissions.size
    assert_equal "initial", last_message["type"]
    assert_equal %w[cable_metrics events metrics type], last_message.keys.sort
    assert_equal map.id, last_message["metrics"]["network_map_id"]
    assert_equal map.id, last_message["cable_metrics"]["network_map_id"]
    assert_equal map.id, last_message["events"]["network_map_id"]
  end

  test "CA13: any membership role (viewer included) may subscribe" do
    org, map = create_org_with_map("a13v")
    stub_connection current_user: member_of(org, "a13v", role: "viewer")
    subscribe organization_id: org.id, map_id: map.id
    assert subscription.confirmed?
  end

  test "CA13: organization_id and map_id may arrive as strings" do
    org, map = create_org_with_map("a13s")
    stub_connection current_user: member_of(org, "a13s")
    subscribe organization_id: org.id.to_s, map_id: map.id.to_s
    assert subscription.confirmed?
    assert_has_stream_for map
  end

  test "CA14: global admin (no membership) subscribes to any organization's map" do
    org, map = create_org_with_map("a14")
    stub_connection current_user: create_user("a14.admin", admin: true)

    subscribe organization_id: org.id, map_id: map.id

    assert subscription.confirmed?
    assert_has_stream_for map
    assert_equal "initial", last_message["type"]
  end

  test "CA15: member of organization A is rejected for organization B (even with B's valid map)" do
    org_a, _map_a = create_org_with_map("a15a")
    org_b, map_b = create_org_with_map("a15b")
    stub_connection current_user: member_of(org_a, "a15")

    subscribe organization_id: org_b.id, map_id: map_b.id

    assert subscription.rejected?
    assert_empty transmissions
    assert_no_streams
  end

  test "CA16: member of A is rejected for A's organization_id with a map of B" do
    org_a, _ = create_org_with_map("a16a")
    _org_b, map_b = create_org_with_map("a16b")
    stub_connection current_user: member_of(org_a, "a16")

    subscribe organization_id: org_a.id, map_id: map_b.id

    assert subscription.rejected?
    assert_empty transmissions
    assert_no_streams
  end

  test "CA17: missing, blank or non-existent organization_id/map_id are rejected" do
    org, map = create_org_with_map("a17")
    user = member_of(org, "a17")
    stub_connection current_user: user
    missing_id = [ Organization.maximum(:id), NetworkMap.maximum(:id) ].max + 1000

    [
      {},
      { map_id: map.id },
      { organization_id: org.id },
      { organization_id: "", map_id: map.id },
      { organization_id: org.id, map_id: "" },
      { organization_id: missing_id, map_id: map.id },
      { organization_id: org.id, map_id: missing_id }
    ].each do |params|
      subscribe(**params)
      assert subscription.rejected?, "expected rejection for #{params.inspect}"
      assert_empty transmissions
    end
  end

  test "CA17: admin with non-existent organization or map is rejected" do
    org, map = create_org_with_map("a17adm")
    stub_connection current_user: create_user("a17.admin", admin: true)
    missing_id = [ Organization.maximum(:id), NetworkMap.maximum(:id) ].max + 1000

    subscribe organization_id: missing_id, map_id: map.id
    assert subscription.rejected?
    subscribe organization_id: org.id, map_id: missing_id
    assert subscription.rejected?
  end

  test "CA18: refresh transmits type refresh with metrics, cable_metrics and events" do
    org, map = create_org_with_map("a18")
    stub_connection current_user: member_of(org, "a18")
    subscribe organization_id: org.id, map_id: map.id

    perform :refresh

    assert_equal 2, transmissions.size
    assert_equal "refresh", last_message["type"]
    assert_equal %w[cable_metrics events metrics type], last_message.keys.sort
  end

  # DIVERGENCE from the REQ text of CA18 (reported to the Maestro): `refresh(data = {})` has arity -1, so
  # ActionCable's dispatch_action calls it WITHOUT the payload and `since` is never applied. Today every
  # refresh returns the latest events regardless of `since`. Characterized as-is, not fixed.
  test "CA18: refresh ignores the since param today (valid ISO8601 and invalid values alike); never raises" do
    org, map = create_org_with_map("a18s")
    old = map.network_cable_events.create!(event_type: "created", occurred_at: 2.hours.ago, actor: "old@example.com", notes: "old")
    recent = map.network_cable_events.create!(event_type: "updated", occurred_at: 10.minutes.ago, actor: "recent@example.com", notes: "recent")
    stub_connection current_user: member_of(org, "a18s")
    subscribe organization_id: org.id, map_id: map.id
    all_ids = [ recent.id, old.id ]

    perform :refresh
    assert_equal all_ids, last_message["events"]["cable_events"].map { |e| e["id"] }

    perform :refresh, since: 1.hour.ago.iso8601
    assert_equal "refresh", last_message["type"]
    assert_equal all_ids, last_message["events"]["cable_events"].map { |e| e["id"] }, "since is currently not applied by the channel action"

    assert_nothing_raised { perform :refresh, since: "not-a-date" }
    assert_equal "refresh", last_message["type"]
    assert_equal all_ids, last_message["events"]["cable_events"].map { |e| e["id"] }
  end

  test "CA18: the since filter itself works when the builder receives it (RecentEventsPayloadBuilder)" do
    _org, map = create_org_with_map("a18b")
    map.network_cable_events.create!(event_type: "created", occurred_at: 2.hours.ago)
    recent = map.network_cable_events.create!(event_type: "updated", occurred_at: 10.minutes.ago)

    filtered = NetworkMaps::RecentEventsPayloadBuilder.new(network_map: map, since: 1.hour.ago.iso8601).call
    assert_equal [ recent.id ], filtered[:cable_events].map { |e| e[:id] }

    ignored = NetworkMaps::RecentEventsPayloadBuilder.new(network_map: map, since: "not-a-date").call
    assert_equal 2, ignored[:cable_events].size
  end

  test "CA18: refresh on a rejected subscription transmits nothing" do
    org, _ = create_org_with_map("a18r")
    stub_connection current_user: member_of(org, "a18r")
    subscribe organization_id: org.id, map_id: 0
    assert subscription.rejected?
    assert_empty transmissions
  end

  test "CA19: unsubscribe leaves no streams; broadcasting to the map no longer reaches the subscription" do
    org, map = create_org_with_map("a19")
    stub_connection current_user: member_of(org, "a19")
    subscribe organization_id: org.id, map_id: map.id
    assert_has_stream_for map

    unsubscribe

    assert_no_streams
    assert_empty subscription.streams
  end

  test "CA20: subscription streams only its own map (isolation between maps/organizations)" do
    org_a, map_a = create_org_with_map("a20a")
    _org_b, map_b = create_org_with_map("a20b")
    stub_connection current_user: member_of(org_a, "a20")

    subscribe organization_id: org_a.id, map_id: map_a.id

    assert_equal [ MapChannel.broadcasting_for(map_a) ], subscription.streams
    assert_not_includes subscription.streams, MapChannel.broadcasting_for(map_b)
    assert_not_equal MapChannel.broadcasting_for(map_a), MapChannel.broadcasting_for(map_b)
  end

  test "O3 (observation): events payload exposes actor and notes to every subscriber of the map" do
    org, map = create_org_with_map("o3")
    map.network_cable_events.create!(event_type: "created", occurred_at: 1.minute.ago, actor: "operator@example.com", notes: "synthetic note")
    stub_connection current_user: member_of(org, "o3", role: "viewer")

    subscribe organization_id: org.id, map_id: map.id

    event = last_message["events"]["cable_events"].first
    assert_equal "operator@example.com", event["actor"]
    assert_equal "synthetic note", event["notes"]
  end
end
