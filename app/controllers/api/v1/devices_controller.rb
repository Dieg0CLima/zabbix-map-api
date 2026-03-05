class Api::V1::DevicesController < ApplicationController
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_device, only: %i[show update destroy]
  before_action :require_editor_or_admin!, only: %i[create update destroy]

  def index
    render json: { data: scoped_devices.includes(:site).order(:id).map { |device| device_payload(device) } }, status: :ok
  end

  def show
    render json: { data: device_payload(@device) }, status: :ok
  end

  def create
    return if ensure_organization_context_for_creation!

    device = Devices::Create.new(organization: current_organization, payload: permitted_device_payload.to_h).call
    render json: { data: device_payload(device) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    device = Devices::Update.new(device: @device, payload: permitted_device_payload.to_h).call
    render json: { data: device_payload(device) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    Devices::Destroy.new(device: @device).call
    head :no_content
  end

  private

  def set_device
    @device = scoped_devices.includes(:site).find(params[:id])
  end

  def scoped_devices
    admin_without_organization_context? ? Device : current_organization.devices
  end

  def permitted_device_payload
    params.require(:device).permit(:external_id, :name, :site_id, :device_type, :zabbix_ref, :status, metadata: {})
  end

  def device_payload(device)
    Devices::PayloadBuilder.new(device:).call
  end
end
