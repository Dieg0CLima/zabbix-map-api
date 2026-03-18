class Api::V1::DeviceInterfaceSerializer
  def initialize(device_interface)
    @device_interface = device_interface
  end

  def as_json(*)
    {
      id: @device_interface.id,
      device_id: @device_interface.device_id,
      name: @device_interface.name,
      interface_type: @device_interface.interface_type,
      description: @device_interface.description,
      enabled: @device_interface.enabled,
      management: @device_interface.management,
      metadata: @device_interface.metadata,
      created_at: @device_interface.created_at,
      updated_at: @device_interface.updated_at
    }
  end
end
