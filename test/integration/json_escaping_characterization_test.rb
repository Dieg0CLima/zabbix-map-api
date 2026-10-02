require "test_helper"

# REQ-004 characterization of JSON escaping (current behavior with load_defaults 8.0 on Rails 8.1.x).
# These tests read RAW serialized strings, never the decoded hash, and must keep passing unchanged after
# `load_defaults 8.1` + the explicit escape_json_responses / escape_js_separators_in_json = true pins.
# Texts are synthetic.
class JsonEscapingCharacterizationTest < ActionDispatch::IntegrationTest
  # Built from code points on purpose: no invisible separator characters or ambiguous backslash escapes in the source.
  BACKSLASH = 92.chr
  U2028 = [ 0x2028 ].pack("U").freeze
  U2029 = [ 0x2029 ].pack("U").freeze
  # Free text with <, >, &, double quote, U+2028 and U+2029.
  NASTY = "A<b>&" + 34.chr + "q" + 34.chr + U2028 + "x" + U2029 + "y"

  # Raw escapes expected today: a literal backslash followed by "u" + 4 hex digits (and backslash-quote for quotes).
  ESCAPES = {
    "<" => "#{BACKSLASH}u003c",
    ">" => "#{BACKSLASH}u003e",
    "&" => "#{BACKSLASH}u0026",
    U2028 => "#{BACKSLASH}u2028",
    U2029 => "#{BACKSLASH}u2029"
  }.freeze
  ESCAPED_QUOTE = "#{BACKSLASH}" + 34.chr

  setup do
    @user = User.create!(email: "json.escape.#{SecureRandom.hex(3)}@example.com", password: "password", password_confirmation: "password")
    @organization = Organization.create!(name: "Org JSON #{SecureRandom.hex(3)}")
    Membership.create!(user: @user, organization: @organization, role: "admin")

    post "/api/v1/users/sign_in", params: { user: { email: @user.email, password: "password", organization_id: @organization.id } }
    @auth_headers = response.headers.slice("Authorization")
  end

  def assert_escaped_raw(raw)
    ESCAPES.each do |char, escaped|
      assert raw.include?(escaped), "missing escape #{escaped.bytes.inspect}"
      assert_not raw.include?(char), "literal char #{char.bytes.inspect} not escaped"
    end
    assert raw.include?(ESCAPED_QUOTE + "q" + ESCAPED_QUOTE), "double quotes not escaped as backslash-quote"
  end

  test "CA6: GET site (render json:) escapes <, >, &, U+2028, U+2029 in the raw body and round-trips through JSON.parse" do
    site = @organization.sites.create!(name: NASTY, external_id: "json-escape-#{SecureRandom.hex(3)}")

    get "/api/v1/sites/#{site.id}", headers: @auth_headers

    assert_response :ok
    assert_escaped_raw response.body
    assert_equal NASTY, JSON.parse(response.body).dig("data", "name")
  end

  test "CA6: POST site echoes the same free text with the same raw escapes" do
    post "/api/v1/sites", params: { organization_id: @organization.id, site: { name: NASTY } }, headers: @auth_headers

    assert_response :created
    assert_escaped_raw response.body
    assert_equal NASTY, JSON.parse(response.body).dig("data", "site", "name")
  end

  test "CA6: GET sites index escapes the same characters in a list response" do
    @organization.sites.create!(name: NASTY, external_id: "json-escape-#{SecureRandom.hex(3)}")

    get "/api/v1/sites", headers: @auth_headers

    assert_response :ok
    assert_escaped_raw response.body
    assert_equal [ NASTY ], JSON.parse(response.body)["data"].map { |s| s["name"] }
  end

  test "CA7: cable event notes/actor are escaped in the raw JSON the cable serializes (builder payload)" do
    map = @organization.network_maps.create!(name: "Map JSON #{SecureRandom.hex(3)}")
    map.network_cable_events.create!(event_type: "created", occurred_at: 1.minute.ago, actor: "operator@example.com", notes: NASTY)

    payload = {
      type: "refresh",
      metrics: NetworkMaps::MetricsPayloadBuilder.new(network_map: map).call,
      cable_metrics: NetworkMaps::CableMetricsPayloadBuilder.new(network_map: map).call,
      events: NetworkMaps::RecentEventsPayloadBuilder.new(network_map: map).call
    }
    raw = ActiveSupport::JSON.encode(payload) # what ActionCable's transmit/broadcast_to serialize

    assert_escaped_raw raw
    assert_equal NASTY, JSON.parse(raw).dig("events", "cable_events", 0, "notes")
  end

  test "CA7: the string actually broadcast by MapMetricsBroadcastJob carries the same escapes" do
    map = @organization.network_maps.create!(name: "Map JSON job #{SecureRandom.hex(3)}")
    map.network_cable_events.create!(event_type: "created", occurred_at: 1.minute.ago, actor: "operator@example.com", notes: NASTY)
    stream = MapChannel.broadcasting_for(map)

    MapMetricsBroadcastJob.perform_now(map.id)

    raw = ActionCable.server.pubsub.broadcasts(stream).first
    assert_kind_of String, raw
    assert_escaped_raw raw
    assert_equal NASTY, JSON.parse(raw).dig("events", "cable_events", 0, "notes")
  ensure
    ActionCable.server.pubsub.clear_messages(stream) if stream
  end
end
