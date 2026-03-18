module Devices
  class Create
    def initialize(organization:, payload:)
      @organization = organization
      @payload = payload
    end

    def call
      device = @organization.devices.new(@payload)
      device.save!
      device
    end
  end
end
