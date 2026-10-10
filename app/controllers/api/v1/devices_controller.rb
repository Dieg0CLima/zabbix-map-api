class Api::V1::DevicesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy site_link removal_impact zabbix_candidates]
  before_action :set_device, only: %i[show dashboard update destroy site_link removal_impact zabbix_candidates]

  def index
    devices = current_organization.devices.includes(:zabbix_host_link).order(:id)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?
    devices = devices.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: devices.map { |device| Api::V1::DeviceSerializer.new(device).as_json })
  end

  def dropdown
    devices = current_organization.devices.includes(:site, :zabbix_host_link).order(:name)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?
    devices = devices.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    render_data(data: devices.limit(50).map { |device| Devices::DropdownPayloadBuilder.new(device).call })
  end

  def show
    render_data(data: Api::V1::DeviceSerializer.new(@device).as_json)
  end

  def dashboard
    payload = Devices::DashboardPayloadBuilder.new(device: @device, limit: dashboard_limit).call
    render_data(data: payload)
  end

  def create
    device, marker = Devices::CreateDevice.new(organization: current_organization, params: device_params.to_h.deep_symbolize_keys, map_context: map_context_params.to_h.deep_symbolize_keys, actor: current_user).call
    render_data(data: { device: Api::V1::DeviceSerializer.new(device).as_json, marker: marker && Api::V1::MapElementSerializer.new(marker).as_json }, status: :created)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def update
    service = Devices::UpdateDevice.new(device: @device, params: device_params.to_h.deep_symbolize_keys, actor: current_user)
    device = service.call
    render_data(data: Api::V1::DeviceSerializer.new(device).as_json, meta: { removed_monitoring: service.removed_monitoring })
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def removal_impact
    render_data(data: Devices::RemovalImpact.new(device: @device).call)
  end

  def destroy
    impact = Devices::DestroyDevice.new(device: @device).call(confirm: removal_confirmed?)
    render_data(data: { removed: true, impact: impact })
  rescue Devices::DestroyDevice::ConfirmationRequired => e
    render_removal_needs_confirmation(e.impact)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
    render_removal_failed(:unprocessable_entity)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("[DevicesController#destroy] #{e.class}")
    render_removal_failed(:internal_server_error)
  end

  def zabbix_candidates
    connection = candidates_connection
    return if performed?

    ip = candidates_ip
    return if performed?

    candidates = Devices::ZabbixCandidates.new(device: @device, connection: connection, ip: ip).call
    render_data(data: candidates)
  rescue Zabbix::HostCandidatesFetcher::Error
    render_errors(status: :service_unavailable, errors: [ { detail: "Não foi possível consultar o Zabbix agora. Tente novamente em instantes; nenhum dado do equipamento foi alterado." } ])
  end

  def site_link
    site = params[:site_id].present? ? find_record(current_organization.sites, params[:site_id]) : nil
    return if performed?

    device = Devices::RelinkDeviceToSite.new(device: @device, site:).call
    render_data(data: Api::V1::DeviceSerializer.new(device).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  private

  def removal_confirmed?
    [ true, "true" ].include?(params[:confirm])
  end

  def render_removal_needs_confirmation(impact)
    detail = removal_confirmation_text(impact)
    render_errors(
      status: :unprocessable_entity,
      code: "DEVICE_REMOVAL_NEEDS_CONFIRMATION",
      errors: [ { code: "DEVICE_REMOVAL_NEEDS_CONFIRMATION", detail: detail, meta: { impact: impact } } ],
      meta: { impact: impact }
    )
  end

  def removal_confirmation_text(impact)
    zabbix_links = impact[:zabbix_links].values.sum
    parts = []
    parts << "#{impact[:maps].size} mapa(s)" if impact[:maps].any?
    parts << "#{zabbix_links} vínculo(s) com o Zabbix" if zabbix_links.positive?
    parts << "#{impact[:network_links]} link(s) de rede" if impact[:network_links].positive?
    text = "Este equipamento está em uso (#{parts.join(', ')}). Confirme a remoção para apagar esses registros."
    text += " #{impact[:cables_left_without_endpoint]} cabo(s) ficarão sem ponta." if impact[:cables_left_without_endpoint].positive?
    "#{text} Esta ação não altera o Zabbix e não pode ser desfeita."
  end

  def render_removal_failed(status)
    render_errors(
      status: status,
      code: "DEVICE_REMOVAL_FAILED",
      errors: [ { code: "DEVICE_REMOVAL_FAILED", detail: "Não foi possível remover o equipamento. Nenhuma alteração foi feita. Tente novamente; se o erro persistir, contate o suporte." } ]
    )
  end

  def candidates_connection
    if params[:zabbix_connection_id].present?
      connection = current_organization.zabbix_connections.find_by(id: params[:zabbix_connection_id])
      return connection if connection

      render_errors(status: :not_found, errors: [ { detail: "Conexão Zabbix não encontrada" } ])
      return
    end

    connection = @device.zabbix_connection
    return connection if connection

    render_errors(status: :unprocessable_entity, errors: [ { source: :zabbix_connection_id, detail: "Informe a conexão Zabbix (zabbix_connection_id): o equipamento ainda não está vinculado a um host." } ])
    nil
  end

  def candidates_ip
    ip = params[:ip].to_s.strip.presence || @device.management_ip.to_s.strip.presence
    if ip.nil?
      render_errors(status: :unprocessable_entity, errors: [ { source: :ip, detail: "Informe o IP: o equipamento não tem IP de gerência cadastrado." } ])
      return
    end
    return ip if valid_ip?(ip)

    render_errors(status: :unprocessable_entity, errors: [ { source: :ip, detail: "IP inválido. Use um endereço IPv4 ou IPv6 completo, sem máscara." } ])
    nil
  end

  def valid_ip?(value)
    return false unless value.match?(/\A[0-9a-fA-F:.]+\z/)

    IPAddr.new(value)
    true
  rescue IPAddr::Error
    false
  end

  def dashboard_limit
    limit = params[:limit] || params.dig(:dashboard, :limit)
    return nil unless limit.present?
    limit.to_i
  end

  def set_device
    @device = find_record(current_organization.devices, params[:id])
  end

  def device_params
    raw = params.require(:device)
    attributes = {}
    allowed_keys = %i[site_id name hostname role vendor model serial_number management_ip status zabbix_connection_id zabbix_host_id]
    allowed_keys.each { |key| attributes[key] = raw[key] if raw.key?(key) }
    attributes[:metadata] = normalized_metadata(raw[:metadata]) if raw.key?(:metadata)
    attributes
  end

  def map_context_params
    raw = params.fetch(:map_context, ActionController::Parameters.new)
    raw[:metadata] = {} if raw.key?(:metadata) && raw[:metadata].nil?
    raw.permit(:add_to_map, :network_map_id, :label_override, :color_override, :icon_override, metadata: {}, position: %i[lat lng x y])
  end

  def normalized_metadata(metadata)
    return {} if metadata.nil?
    return {} unless metadata.respond_to?(:to_unsafe_h) || metadata.respond_to?(:to_h)

    hash = metadata.respond_to?(:to_unsafe_h) ? metadata.to_unsafe_h : metadata.to_h
    hash.deep_transform_values do |value|
      case value
      when String, Numeric, TrueClass, FalseClass, NilClass
        value
      else
        value.to_s
      end
    end
  end
end
