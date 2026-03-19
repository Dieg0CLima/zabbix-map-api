class Zabbix::HostPayloadBuilder
  INTERFACE_TYPE_MAP = {
    "1" => "agent",
    "2" => "snmp",
    "3" => "ipmi",
    "4" => "jmx"
  }.freeze

  def initialize(host:)
    @host = host
  end

  def dropdown_payload
    {
      value: hostid,
      label: display_name,
      hostid:,
      name: display_name,
      status: normalized_status,
      available: available?,
      metadata: {
        interfaces: interfaces_payload,
        groups: groups_payload,
        templates: templates_payload
      }
    }
  end

  def details_payload
    {
      hostid:,
      name: display_name,
      host: technical_host,
      status: normalized_status,
      available: available?,
      interfaces: interfaces_payload,
      inventory: inventory_payload,
      metadata: metadata_payload,
      suggested_device_attributes: suggested_device_attributes
    }
  end

  private

  def hostid
    @host.hostid.to_s
  end

  def display_name
    @host.name.presence || technical_host
  end

  def technical_host
    host_metadata["host"].presence || host_metadata[:host].presence || @host.name
  end

  def normalized_status
    status_value = @host.status.to_s
    status_value == "1" || status_value.casecmp("disabled").zero? ? "disabled" : "enabled"
  end

  def available?
    value = @host.available
    return value if value == true || value == false

    value.to_s.strip.downcase.in?(["1", "true", "up", "available", "enabled"])
  end

  def interfaces_payload
    Array(@host.interfaces).map do |interface|
      iface = interface.with_indifferent_access
      {
        ip: iface[:ip].presence || iface[:dns],
        dns: iface[:dns].to_s,
        type: INTERFACE_TYPE_MAP.fetch(iface[:type].to_s, iface[:type].presence || "unknown"),
        main: truthy?(iface[:main])
      }
    end
  end

  def groups_payload
    Array(host_metadata["groups"] || host_metadata[:groups]).map do |group|
      item = group.with_indifferent_access
      {
        groupid: item[:groupid].to_s,
        name: item[:name].to_s
      }
    end
  end

  def templates_payload
    Array(host_metadata["parentTemplates"] || host_metadata[:parentTemplates] || host_metadata["templates"] || host_metadata[:templates]).map do |template|
      item = template.with_indifferent_access
      {
        templateid: item[:templateid].to_s,
        name: item[:name].to_s
      }
    end
  end

  def inventory_payload
    raw = (host_metadata["inventory"] || host_metadata[:inventory] || {}).with_indifferent_access
    {
      vendor: raw[:vendor].presence || raw[:vendor_name].presence || raw[:hw_vendor].presence,
      model: raw[:model].presence || raw[:type].presence || raw[:model_name].presence
    }.compact
  end

  def metadata_payload
    host_metadata.except("inventory", :inventory, "groups", :groups, "parentTemplates", :parentTemplates, "templates", :templates)
  end

  def suggested_device_attributes
    {
      name: display_name,
      hostname: technical_host,
      management_ip: primary_interface_ip,
      vendor: inventory_payload[:vendor],
      model: inventory_payload[:model]
    }.compact
  end

  def primary_interface_ip
    primary = interfaces_payload.find { |iface| iface[:main] }
    primary ||= interfaces_payload.find { |iface| iface[:ip].present? }
    primary&.dig(:ip)
  end

  def host_metadata
    @host.metadata || {}
  end

  def truthy?(value)
    value == true || value.to_s.strip.downcase.in?(["1", "true", "yes"])
  end
end
