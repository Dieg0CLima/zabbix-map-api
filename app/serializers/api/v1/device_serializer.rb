class Api::V1::DeviceSerializer
  def initialize(device)
    @device = device
  end

  def as_json(*)
    {
      id: @device.id,
      organization_id: @device.organization_id,
      site_id: @device.site_id,
      name: @device.name,
      hostname: @device.hostname,
      role: @device.role,
      vendor: @device.vendor,
      model: @device.model,
      serial_number: @device.serial_number,
      management_ip: @device.management_ip,
      status: @device.status,
      metadata: @device.metadata,
      created_at: @device.created_at,
      updated_at: @device.updated_at
    }
  end
end
