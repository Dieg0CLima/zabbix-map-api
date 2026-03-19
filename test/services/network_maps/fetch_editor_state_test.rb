require "test_helper"

class NetworkMapsFetchEditorStateTest < ActiveSupport::TestCase
  test "filters device markers out of renderable editor elements" do
    organization = Organization.create!(name: "Org Query", slug: "org-query")
    membership = Membership.create!(user: User.create!(email: "query@example.com", password: "password", password_confirmation: "password"), organization:, role: "admin")
    network_map = NetworkMap.create!(organization:, name: "Ops")
    site = Site.create!(organization:, name: "Site B", slug: "site-b")
    device = Device.create!(organization:, site:, name: "RT-01", role: "router", status: "active")

    network_map.map_nodes.create!(mappable: site, label: site.name, node_kind: "gateway", x: 1, y: 1, lat: 1, lng: 1, icon: "pi-building", color: "#111111", size: 30)
    network_map.map_nodes.create!(mappable: device, label: device.name, node_kind: "router", x: 2, y: 2, lat: 2, lng: 2, icon: "pi-box", color: "#222222", size: 30)

    payload = NetworkMaps::FetchEditorState.new(network_map:, current_membership: membership).call

    assert_equal 1, payload[:elements].size
    assert_equal "Site", payload[:elements].first[:mappable_type]
    assert_equal 1, payload[:devices].size
  end
end
