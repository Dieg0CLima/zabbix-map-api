# Shared fixtures-by-hand for the REQ-009 (device replacement) acceptance tests.
# No network: Zabbix collaborators are always stubbed by the tests that include this module.
module DeviceReplacementSupport
  FakeHostDetails = Struct.new(:payload) { def reference_payload = payload }
  FakeCandidates = Struct.new(:result) do
    def call
      raise result if result.is_a?(Exception)

      result
    end
  end

  def setup_replacement_world
    @org = Organization.create!(name: "Org Troca #{SecureRandom.hex(3)}")
    @other_org = Organization.create!(name: "Org Troca B #{SecureRandom.hex(3)}")
    @site = @org.sites.create!(name: "Site Ferreiros", slug: "site-ferreiros-#{SecureRandom.hex(3)}")
    @connection = build_connection(@org, "Zabbix A")
    @other_connection = build_connection(@other_org, "Zabbix B")

    @editor = create_member("editor", @org, "editor")
    @admin = create_member("admin", @org, "admin")
    @viewer = create_member("viewer", @org, "viewer")
    @foreign_editor = create_member("foreign", @other_org, "editor")
    @auth = {
      editor: sign_in_as(@editor, @org),
      admin: sign_in_as(@admin, @org),
      viewer: sign_in_as(@viewer, @org),
      foreign: sign_in_as(@foreign_editor, @other_org)
    }
  end

  def build_connection(org, name)
    org.zabbix_connections.create!(
      name: name, status: "active", connection_mode: "database", db_adapter: "postgresql",
      db_host: "127.0.0.1", db_port: 5432, db_name: "zabbix", db_username: "zabbix", db_password: "secret"
    )
  end

  def create_member(label, org, role)
    user = User.create!(email: "#{label}.#{SecureRandom.hex(4)}@example.com", password: "Password!123", password_confirmation: "Password!123")
    Membership.create!(user: user, organization: org, role: role)
    user
  end

  def sign_in_as(user, org)
    post "/api/v1/users/sign_in", params: { user: { email: user.email, password: "Password!123", organization_id: org.id } }, as: :json
    { "Authorization" => response.headers["Authorization"] }
  end

  def build_device(name: "Switch Guarda Ferreiros", org: @org, **attrs)
    org.devices.create!({ name: name, role: "switch", status: "active", hostname: "sw-guarda-01", vendor: "Huawei", model: "S5720", serial_number: "SN-ANTIGO", management_ip: "10.0.0.1" }.merge(attrs))
  end

  def link_host(device, connection, hostid, name: "HOST #{hostid}", org: @org)
    ZabbixLink.create!(
      organization: org, zabbix_connection: connection, linkable: device, resource_type: "host",
      external_id: hostid, name: name, metadata: { "hostid" => hostid, "synced_at" => 2.days.ago.iso8601 }
    )
  end

  def add_interface_with_link(device, connection, name: "GigabitEthernet0/0/1")
    interface = device.device_interfaces.create!(name: name)
    link = ZabbixLink.create!(
      organization: device.organization, zabbix_connection: connection, linkable: interface, resource_type: "interface",
      external_id: "if-#{SecureRandom.hex(3)}", name: name, metadata: {}
    )
    [ interface, link ]
  end

  def build_item(connection, itemid)
    host = connection.zabbix_hosts.find_or_create_by!(hostid: "zbx-host-#{connection.id}") { |h| h.assign_attributes(name: "ZBX", status: "0", available: "1") }
    connection.zabbix_items.create!(zabbix_host: host, itemid: itemid, name: "Item #{itemid}", key_: "net.if.in[#{itemid}]", value_type: "3", units: "bps", status: "0", state: "0")
  end

  def build_map(name, connection: @connection, org: @org)
    org.network_maps.create!(name: name, source_type: "manual", zabbix_connection: connection, active_base_layer: "standard")
  end

  def build_node(network_map, label, mappable: nil, external_id: nil)
    network_map.map_nodes.create!(
      mappable: mappable, label: label, node_kind: "switch", x: 1, y: 1, lat: 1, lng: 1, icon: "pi-server", color: "#111111",
      size: 30, external_id: external_id || "node-#{SecureRandom.hex(4)}", metadata: {}
    )
  end

  def build_cable(network_map, source_node, target_node)
    network_map.network_cables.create!(source_node: source_node, target_node: target_node, cable_type: "fiber", status: "active")
  end

  # `network_links` has no model; rows are created with SQL.
  def insert_network_link(org, source_device_id:, target_device_id:)
    conn = ActiveRecord::Base.connection
    conn.execute(<<~SQL.squish)
      INSERT INTO network_links (organization_id, external_id, source_device_id, target_device_id, link_type, status, metadata, created_at, updated_at)
      VALUES (#{org.id.to_i}, #{conn.quote("link-#{SecureRandom.hex(4)}")}, #{source_device_id ? source_device_id.to_i : 'NULL'}, #{target_device_id ? target_device_id.to_i : 'NULL'}, 'logical', 'planned', '{}', NOW(), NOW())
    SQL
  end

  def network_links_count(device_id)
    ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM network_links WHERE source_device_id = #{device_id.to_i} OR target_device_id = #{device_id.to_i}").to_i
  end

  def host_payload(hostid, name:, ip: "10.0.0.1", vendor: "Huawei", model: "S6730")
    {
      hostid: hostid, name: name, status: "enabled", available: true,
      interfaces: [ { ip: ip, dns: "", type: "snmp", main: true } ],
      metadata: { host: name.downcase, inventory: { vendor: vendor, model: model } }
    }
  end

  # Stubs the single-host lookup used when (re)linking; unknown ids behave like a host that does not exist.
  def with_host_details(payloads_by_hostid, &block)
    factory = lambda do |connection:, hostid:|
      payload = payloads_by_hostid[hostid.to_s]
      if payload.is_a?(Exception)
        raise_on_call = Object.new
        raise_on_call.define_singleton_method(:reference_payload) { raise payload }
        raise_on_call
      elsif payload
        FakeHostDetails.new(payload)
      else
        missing = Object.new
        missing.define_singleton_method(:reference_payload) { raise Zabbix::HostDetailsFetcher::Error, "Host not found" }
        missing
      end
    end
    Zabbix::HostDetailsFetcher.stub(:new, factory, &block)
  end

  # Any attempt to open a Zabbix connection fails the test: used for flows that must be local-only.
  def without_zabbix(&block)
    Zabbix::DatabaseConnection.stub(:new, ->(*, **) { flunk "unexpected Zabbix connection" }, &block)
  end

  def json
    response.parsed_body
  end

  def impact_from(body)
    body.dig("meta", "impact") || body.dig("errors", 0, "meta", "impact")
  end

  def auth_for(role)
    @auth.fetch(role)
  end
end
