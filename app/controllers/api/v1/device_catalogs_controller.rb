class Api::V1::DeviceCatalogsController < Api::V1::BaseController
  def index
    payload = Devices::CatalogsFetcher.new.call
    render_data(data: Api::V1::DeviceCatalogsSerializer.new(payload).as_json)
  end
end
