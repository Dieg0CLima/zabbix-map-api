module Devices
  class Destroy
    def initialize(device:)
      @device = device
    end

    def call
      @device.destroy!
    end
  end
end
