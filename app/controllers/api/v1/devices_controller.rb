class Api::V1::DevicesController < ApplicationController
  include DomainErrorHandler
  include OrganizationScoped

  before_action :authenticate_user!
  before_action :ensure_organization_access!
  before_action :set_device, only: %i[show update destroy]

  def index
    devices = scoped_devices.order(:name)
    render json: { data: devices.map { |d| device_payload(d) } }, status: :ok
  end

  def show
    render json: { data: device_payload(@device) }, status: :ok
  end

  def create
    device = scoped_devices.create!(permitted_device_payload)
    render json: { data: device_payload(device) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def update
    @device.update!(permitted_device_payload)
    render json: { data: device_payload(@device) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def destroy
    @device.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotDestroyed => e
    render_validation_error(e.record, message: "Não foi possível remover o dispositivo")
  end

  private

  def set_device
    @device = scoped_devices.find(params[:id])
  end

  def permitted_device_payload
    params.require(:device).permit(:name, :external_id, :device_type, :site_id, :zabbix_ref, :status, metadata: {})
  end

  def device_payload(device)
    {
      id: device.id,
      organization_id: device.organization_id,
      site_id: device.site_id,
      external_id: device.external_id,
      name: device.name,
      device_type: device.device_type,
      zabbix_ref: device.zabbix_ref,
      status: device.status,
      metadata: device.metadata,
      created_at: device.created_at,
      updated_at: device.updated_at
    }
  end
end
