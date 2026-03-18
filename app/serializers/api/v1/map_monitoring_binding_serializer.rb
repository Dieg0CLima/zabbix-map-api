class Api::V1::MapMonitoringBindingSerializer
  def initialize(binding)
    @binding = binding
  end

  def as_json(*)
    {
      id: @binding.id,
      map_node_id: @binding.map_node_id,
      zabbix_link_id: @binding.zabbix_link_id,
      metric_type: @binding.metric_type,
      display_mode: @binding.display_mode,
      label: @binding.label,
      severity_source: @binding.severity_source,
      metadata: @binding.metadata,
      created_at: @binding.created_at,
      updated_at: @binding.updated_at
    }
  end
end
