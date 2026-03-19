class Zabbix::Observability::FetchDeviceSummary < Zabbix::Observability::BaseFetch
  def initialize(device:, events_service: Zabbix::Observability::FetchEvents, interfaces_service: Zabbix::Observability::FetchInterfaces, metrics_service: Zabbix::Observability::FetchMetrics, recent_data_service: Zabbix::Observability::FetchRecentData, **kwargs)
    super(device:, **kwargs)
    @events_service = events_service
    @interfaces_service = interfaces_service
    @metrics_service = metrics_service
    @recent_data_service = recent_data_service
  end

  def call
    with_cache("summary") do
      events = @events_service.new(device:).call
      metrics = @metrics_service.new(device:).call
      interfaces_payload = @interfaces_service.new(device:).call
      interfaces = interfaces_payload.fetch(:data)
      recent_data = @recent_data_service.new(device:).call

      {
        status: summarize_status(events:),
        events:,
        interfaces:,
        metrics:,
        recent_data:,
        zabbix_unavailable: events[:zabbix_unavailable] || metrics[:zabbix_unavailable] || interfaces_payload[:zabbix_unavailable] || recent_data[:zabbix_unavailable],
        last_updated_at: Time.current.utc.iso8601
      }
    end
  rescue StandardError => e
    Rails.logger.warn("[Zabbix::Observability] summary fallback for device=#{device.id}: #{e.class}: #{e.message}")
    {
      status: "unknown",
      events: @events_service.new(device:).send(:default_payload),
      interfaces: [],
      metrics: @metrics_service.new(device:).send(:default_payload),
      recent_data: @recent_data_service.new(device:).send(:default_payload),
      zabbix_unavailable: true,
      last_updated_at: Time.current.utc.iso8601
    }
  end

  private

  def summarize_status(events:)
    return "unknown" if events[:zabbix_unavailable]
    return "problem" if events[:active_problems].to_i.positive?

    "ok"
  end
end
