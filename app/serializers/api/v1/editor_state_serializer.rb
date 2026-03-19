class Api::V1::EditorStateSerializer
  def initialize(map:, elements:, sites:, devices:, zabbix_summary:, capabilities:)
    @map = map
    @elements = elements
    @sites = sites
    @devices = devices
    @zabbix_summary = zabbix_summary
    @capabilities = capabilities
  end

  def as_json(*)
    {
      map: Api::V1::NetworkMapSerializer.new(@map).as_json,
      elements: @elements.map { |element| Api::V1::MapElementSerializer.new(element).as_json },
      sites: @sites.map { |site| Api::V1::SiteSerializer.new(site).as_json },
      devices: @devices.map { |device| Api::V1::DeviceSerializer.new(device).as_json },
      zabbix_summary: @zabbix_summary,
      capabilities: @capabilities
    }
  end
end
