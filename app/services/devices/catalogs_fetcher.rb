class Devices::CatalogsFetcher
  def call
    {
      roles: build_options(Device::ROLES),
      statuses: build_options(Device::STATUSES)
    }
  end

  private

  def build_options(values)
    values.map do |value|
      {
        value:,
        label: I18n.t("devices.catalogs.#{value}", default: value.humanize)
      }
    end
  end
end
