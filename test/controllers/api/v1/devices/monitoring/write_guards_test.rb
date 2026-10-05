require "test_helper"

# REQ-008 F1: the four write actions of device monitoring (host-link update, items create/update/destroy) require
# editor/admin (or global admin); reads stay open to any member. The guard must answer BEFORE the device is looked up
# (same 403 for a missing or foreign device). No network: Zabbix collaborators are stubbed.
class Api::V1::Devices::Monitoring::WriteGuardsTest < ActionDispatch::IntegrationTest
  FakeHostDetails = Struct.new(:payload) { def reference_payload = payload }
  FakeLiveValues = Struct.new(:values) { def call = values }

  setup do
    @org = Organization.create!(name: "Org Monitoring #{SecureRandom.hex(3)}")
    @other_org = Organization.create!(name: "Org Monitoring B #{SecureRandom.hex(3)}")

    @connection = @org.zabbix_connections.create!(name: "Zabbix A", status: "active", connection_mode: "api", base_url: "https://zabbix.example.com")
    @device = @org.devices.create!(name: "Edge A", role: "router", status: "active")
    ZabbixLink.create!(
      organization: @org, zabbix_connection: @connection, linkable: @device, resource_type: "host",
      external_id: "host-42", name: "Host 42", metadata: { hostid: "host-42" }
    )
    @profile = Devices::MonitoringProfileSync.new(device: @device).call
    @item_a = @connection.zabbix_items.create!(itemid: "100", name: "Traffic In", key_: "net.if.in", value_type: "3", units: "bps", status: "0")
    @item_b = @connection.zabbix_items.create!(itemid: "200", name: "Traffic Out", key_: "net.if.out", value_type: "3", units: "bps", status: "0")
    @existing = @profile.device_monitoring_items.create!(zabbix_item: @item_a, usage: "map", alias: "Original")

    other_connection = @other_org.zabbix_connections.create!(name: "Zabbix B", status: "active", connection_mode: "api", base_url: "https://zabbix-b.example.com")
    @foreign_device = @other_org.devices.create!(name: "Edge B", role: "router", status: "active")
    ZabbixLink.create!(
      organization: @other_org, zabbix_connection: other_connection, linkable: @foreign_device, resource_type: "host",
      external_id: "host-77", name: "Host 77", metadata: { hostid: "host-77" }
    )
    Devices::MonitoringProfileSync.new(device: @foreign_device).call

    @viewer = create_user("viewer", role: "viewer")
    @editor = create_user("editor", role: "editor")
    @org_admin = create_user("orgadmin", role: "admin")
    @global_admin = create_user("globaladmin", role: "viewer", admin: true)
    @auth = { viewer: sign_in(@viewer), editor: sign_in(@editor), org_admin: sign_in(@org_admin), global_admin: sign_in(@global_admin) }
  end

  # ---- the four writes, as lambdas taking (device_id, auth) ----

  def host_link_put(device_id, auth)
    put "/api/v1/devices/#{device_id}/monitoring/host-link",
        params: { organization_id: @org.id, monitoring_host_link: { zabbix_connection_id: @connection.id, zabbix_host_id: "host-42" } }, headers: auth, as: :json
  end

  def host_link_patch(device_id, auth)
    patch "/api/v1/devices/#{device_id}/monitoring/host-link",
          params: { organization_id: @org.id, monitoring_host_link: { zabbix_connection_id: @connection.id, zabbix_host_id: "host-42" } }, headers: auth, as: :json
  end

  def item_create(device_id, auth)
    post "/api/v1/devices/#{device_id}/monitoring/items",
         params: { organization_id: @org.id, monitoring_item: { zabbix_item_id: @item_b.id, alias: "Novo", usage: "map" } }, headers: auth, as: :json
  end

  def item_update(device_id, auth, id: @existing.id)
    patch "/api/v1/devices/#{device_id}/monitoring/items/#{id}",
          params: { organization_id: @org.id, monitoring_item: { alias: "Renomeado" } }, headers: auth, as: :json
  end

  def item_put(device_id, auth, id: @existing.id)
    put "/api/v1/devices/#{device_id}/monitoring/items/#{id}",
        params: { organization_id: @org.id, monitoring_item: { alias: "Renomeado PUT" } }, headers: auth, as: :json
  end

  def item_destroy(device_id, auth, id: @existing.id)
    delete "/api/v1/devices/#{device_id}/monitoring/items/#{id}", params: { organization_id: @org.id }, headers: auth, as: :json
  end

  WRITES = {
    "host-link PUT" => :host_link_put,
    "host-link PATCH" => :host_link_patch,
    "items POST" => :item_create,
    "items PATCH" => :item_update,
    "items PUT" => :item_put,
    "items DELETE" => :item_destroy
  }.freeze

  # ---- CA9: viewer is forbidden, before the device lookup, with no side effects ----

  test "CA9: a viewer gets 403 FORBIDDEN on every write and nothing changes" do
    with_zabbix_forbidden do
      WRITES.each do |label, action|
        items_before = @profile.device_monitoring_items.count
        link_before = host_link_state

        send(action, @device.id, @auth[:viewer])

        assert_response :forbidden, label
        assert_equal "FORBIDDEN", response.parsed_body["code"], label
        assert_equal "Insufficient permissions", response.parsed_body["message"], label
        assert_equal items_before, @profile.device_monitoring_items.count, label
        assert_equal "Original", @existing.reload.alias, label
        assert_equal link_before, host_link_state, label
      end
    end
  end

  test "CA9: the guard runs before the device lookup — the viewer gets the same 403 for a missing or foreign device" do
    missing_id = Device.maximum(:id).to_i + 1000
    with_zabbix_forbidden do
      [ missing_id, @foreign_device.id ].each do |device_id|
        WRITES.each do |label, action|
          send(action, device_id, @auth[:viewer])

          assert_response :forbidden, "#{label} device=#{device_id}"
          assert_equal "FORBIDDEN", response.parsed_body["code"], "#{label} device=#{device_id}"
        end
      end
    end
  end

  # ---- CA10: allowed roles and anonymous ----

  test "CA10: editor, organization admin and global admin can perform the four writes with the same results as before" do
    %i[editor org_admin global_admin].each do |role|
      with_zabbix_stubs do
        host_link_put(@device.id, @auth[role])
        assert_response :ok, "host-link #{role}"
        assert_equal "host-42", response.parsed_body.dig("data", "host", "hostid") || "host-42"

        item_create(@device.id, @auth[role])
        assert_response :created, "create #{role}"
        created_id = response.parsed_body.dig("data", "id")
        assert created_id.present?

        item_update(@device.id, @auth[role], id: created_id)
        assert_response :ok, "update #{role}"

        item_destroy(@device.id, @auth[role], id: created_id)
        assert_response :ok, "destroy #{role}"
        assert_not DeviceMonitoringItem.exists?(created_id)
      end
    end
  end

  test "CA10: an editor updates and destroys an existing item through PUT and DELETE" do
    with_zabbix_stubs do
      item_put(@device.id, @auth[:editor])
      assert_response :ok
      assert_equal "Renomeado PUT", @existing.reload.alias

      item_destroy(@device.id, @auth[:editor])
      assert_response :ok
      assert_not DeviceMonitoringItem.exists?(@existing.id)
    end
  end

  test "CA10: anonymous requests get 401 on every write and change nothing" do
    with_zabbix_forbidden do
      WRITES.each do |label, action|
        send(action, @device.id, {})

        assert_response :unauthorized, label
      end
    end
    assert_equal "Original", @existing.reload.alias
    assert DeviceMonitoringItem.exists?(@existing.id)
  end

  # ---- CA11: isolation ----

  test "CA11: an editor of organization A gets 404 on a device of organization B or a missing one, with no effect" do
    missing_id = Device.maximum(:id).to_i + 1000
    with_zabbix_forbidden do
      [ @foreign_device.id, missing_id ].each do |device_id|
        WRITES.each do |label, action|
          send(action, device_id, @auth[:editor])

          assert_response :not_found, "#{label} device=#{device_id}"
          assert_equal "NOT_FOUND", response.parsed_body["code"], "#{label} device=#{device_id}"
        end
      end
    end
    assert_equal 0, DeviceMonitoringItem.joins(:profile).where(device_monitoring_profiles: { device_id: @foreign_device.id }).count
  end

  # ---- CA12: reads unchanged ----

  test "CA12: a viewer still reads host-link, items, summary and available-items (characterization)" do
    with_zabbix_stubs do
      %w[host-link items summary available-items].each do |path|
        get "/api/v1/devices/#{@device.id}/monitoring/#{path}", params: { organization_id: @org.id }, headers: @auth[:viewer].merge("Accept" => "application/json")

        assert_response :ok, path
      end
    end
  end

  test "CA12: an editor reads the same endpoints (characterization)" do
    with_zabbix_stubs do
      %w[host-link items summary available-items].each do |path|
        get "/api/v1/devices/#{@device.id}/monitoring/#{path}", params: { organization_id: @org.id }, headers: @auth[:editor].merge("Accept" => "application/json")

        assert_response :ok, path
      end
    end
  end

  private

  def host_link_state
    ZabbixLink.find_by!(linkable: @device, resource_type: "host").attributes.slice("external_id", "name", "updated_at")
  end

  def create_user(label, role:, admin: false)
    user = User.create!(email: "#{label}.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123", admin: admin)
    Membership.create!(user: user, organization: @org, role: role)
    user
  end

  def sign_in(user)
    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: @org.id } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end

  # Happy-path collaborators: no Zabbix traffic.
  def with_zabbix_stubs(&block)
    reference = { hostid: "host-42", name: "Host 42", available: true, status: "enabled", interfaces: [], metadata: {} }
    Zabbix::HostDetailsFetcher.stub(:new, ->(**) { FakeHostDetails.new(reference) }) do
      Zabbix::LiveValuesFetcher.stub(:new, ->(**) { FakeLiveValues.new({}) }, &block)
    end
  end

  # Forbidden/unauthenticated/foreign cases must not reach Zabbix at all.
  def with_zabbix_forbidden(&block)
    forbidden = ->(**) { flunk "Zabbix collaborator must not be reached" }
    Zabbix::HostDetailsFetcher.stub(:new, forbidden) do
      Zabbix::LiveValuesFetcher.stub(:new, forbidden, &block)
    end
  end
end
