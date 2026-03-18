class Api::V1::DevicesController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_device, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    devices = scoped_devices.includes(:site).order(:name)
    devices = devices.where(site_id: params[:site_id]) if params[:site_id].present?

    render json: { data: devices.map { |d| device_payload(d) } }, status: :ok
  end

  def show
    render json: { data: device_payload(@device) }, status: :ok
  end

  def create
    device = Devices::Create.new(
      organization: current_organization,
      payload:      permitted_device_params.to_h
    ).call

    render json: { data: device_payload(device) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    Devices::Update.new(device: @device, payload: permitted_device_params.to_h).call

    render json: { data: device_payload(@device) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    Devices::Destroy.new(device: @device).call

    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_error(e.record, message: "Não foi possível remover o Device")
  end

  private

  def set_device
    @device = scoped_devices.find_by!(external_id: params[:id])
  rescue ActiveRecord::RecordNotFound
    @device = scoped_devices.find(params[:id]) if params[:id].to_s.match?(/\A\d+\z/)
    raise ActiveRecord::RecordNotFound if @device.blank?
  end

  def scoped_devices
    current_organization.devices
  end

  def permitted_device_params
    params.require(:device).permit(
      :external_id, :site_id, :name, :device_type,
      :zabbix_ref, :zabbix_host_id, :status,
      metadata: {}
    )
  end

  def device_payload(device)
    Devices::PayloadBuilder.new(device:).call
  end
end
