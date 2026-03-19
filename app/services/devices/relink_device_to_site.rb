class Devices::RelinkDeviceToSite
  def initialize(device:, site:)
    @device = device
    @site = site
  end

  def call
    @device.update!(site: @site)
    @device
  end
end
