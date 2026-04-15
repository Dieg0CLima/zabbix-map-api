class Api::V1::Devices::Monitoring::ProfileSerializer
  def initialize(profile)
    @profile = profile
  end

  def as_json(*)
    return {} unless @profile&.linked?

    {
      device_id:            @profile.device_id,
      zabbix_connection_id: @profile.zabbix_connection&.id,
      zabbix_hostid:        @profile.zabbix_hostid,
      host_label:           @profile.host_label,
      metadata:             @profile.host_metadata_with_defaults,
      synced_at:            @profile.synced_at
    }
  end
end
