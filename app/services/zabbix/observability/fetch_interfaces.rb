class Zabbix::Observability::FetchInterfaces < Zabbix::Observability::BaseFetch
  def initialize(device:, metrics_service: Zabbix::Observability::FetchMetrics, **kwargs)
    super(device:, **kwargs)
    @metrics_service = metrics_service
  end

  def call
    with_cache("interfaces") do
      safe_fetch(default: default_payload) do
        traffic_entries = @metrics_service.new(device:).call.fetch(:traffic, [])
        traffic_index = traffic_entries.index_by { |entry| entry[:interface] }

        interfaces = fetch_interfaces.each_with_index.map do |iface, index|
          interface_name = infer_name(iface, traffic_entries[index])
          {
            name: interface_name,
            ip: iface["ip"].presence || iface["dns"],
            main: iface["main"].to_s == "1",
            type: interface_type(iface["type"]),
            traffic: traffic_payload(traffic_index[interface_name]),
            status: interface_status(iface)
          }
        end

        { data: interfaces, zabbix_unavailable: false }
      end
    end
  end

  private

  def fetch_interfaces
    if database_available?
      Zabbix::DatabaseHostDetailsFetcher.new(connection:, hostid:).call[:interfaces].map.with_index do |iface, index|
        {
          "interfaceid" => index.to_s,
          "ip" => iface[:ip],
          "dns" => iface[:dns],
          "main" => iface[:main] ? "1" : "0",
          "type" => iface[:type].to_s,
          "available" => iface[:main] ? "1" : "0"
        }
      end
    elsif api_available?
      client.call("hostinterface.get", {
        hostids: [host_id],
        output: ["interfaceid", "ip", "dns", "main", "type", "available", "error"]
      })
    else
      []
    end
  end

  def default_payload
    { data: [] }
  end

  def infer_name(iface, traffic_entry = nil)
    traffic_entry&.dig(:interface).presence || iface["dns"].presence || iface["ip"].presence || "interface-#{iface['interfaceid']}"
  end

  def interface_type(value)
    {
      "1" => "agent",
      "2" => "snmp",
      "3" => "ipmi",
      "4" => "jmx"
    }.fetch(value.to_s, "unknown")
  end

  def interface_status(iface)
    iface["available"].to_s == "1" ? "up" : "down"
  end

  def traffic_payload(entry)
    {
      in_bps: entry&.dig(:in_bps),
      out_bps: entry&.dig(:out_bps)
    }
  end
end
