module Devices
  class PayloadBuilder
    def initialize(device:)
      @device = device
    end

    def call
      {
        id:              @device.id,
        organization_id: @device.organization_id,
        site_id:         @device.site_id,
        external_id:     @device.external_id,
        name:            @device.name,
        device_type:     @device.device_type,
        zabbix_ref:      @device.zabbix_ref,
        zabbix_host_id:  @device.zabbix_host_id,
        status:          @device.status,
        metadata:        @device.metadata,
        created_at:      @device.created_at,
        updated_at:      @device.updated_at
      }
    end
  end
end
