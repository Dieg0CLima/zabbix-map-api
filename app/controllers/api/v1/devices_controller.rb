class Api::V1::DevicesController < Api::V1::BaseController
  before_action :require_editor_or_admin!, only: %i[create update destroy site_link]
  before_action :set_device, only: %i[show dashboard update destroy site_link]

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
    device = Devices::UpdateDevice.new(device: @device, params: device_params.to_h.deep_symbolize_keys, actor: current_user).call
    render_data(data: Api::V1::DeviceSerializer.new(device).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @device.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
    render_record_errors(@device)
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
