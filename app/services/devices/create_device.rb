class Devices::CreateDevice
  def initialize(organization:, params:, map_context: nil, actor: nil)
    @organization = organization
    @params = params
    @map_context = map_context || {}
    @actor = actor
  end

  def call
    ActiveRecord::Base.transaction do
      device = @organization.devices.create!(device_attributes)
      Devices::ZabbixHostLinkUpserter.new(device:, organization: @organization, params: @params).call
      Devices::MonitoringProfileSync.new(device: device).call
      device.reload
      marker = attach_to_map(device) if add_to_map?
      [device, marker]
    end
  end

  private

  def device_attributes
    attrs = @params.deep_dup.except(:zabbix_connection_id, :zabbix_host_id)
    attrs[:metadata] = (attrs[:metadata] || {}).merge("created_by_id" => @actor&.id)
    attrs[:external_id] ||= "device-#{SecureRandom.uuid}" if Device.attribute_names.include?("external_id")
    attrs[:status] ||= "active" if Device.attribute_names.include?("status")
    attrs
  end

  def add_to_map?
    ActiveModel::Type::Boolean.new.cast(@map_context[:add_to_map]) && @map_context[:network_map_id].present?
  end

  def attach_to_map(device)
    network_map = @organization.network_maps.find(@map_context[:network_map_id])
    Devices::AttachDeviceToMap.new(network_map:, device:, params: marker_params, actor: @actor).call
  end

  def marker_params
    position = @map_context[:position] || {}
    {
      x: position[:lng] || position[:x],
      y: position[:lat] || position[:y],
      lat: position[:lat] || position[:y],
      lng: position[:lng] || position[:x],
      label_override: @map_context[:label_override],
      color: @map_context[:color_override],
      icon: @map_context[:icon_override],
      metadata: (@map_context[:metadata] || {}).merge("created_by_id" => @actor&.id)
    }
  end
end
