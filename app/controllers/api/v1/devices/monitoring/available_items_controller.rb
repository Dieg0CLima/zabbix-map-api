class Api::V1::Devices::Monitoring::AvailableItemsController < Api::V1::Devices::Monitoring::BaseController
  def index
    result = Devices::Monitoring::AvailableItemsFetcher.new(
      profile:       monitoring_profile,
      limit:         params[:limit],
      force_refresh: params[:refresh].present?
    ).call
    render_data(data: result[:items].map { |item| Api::V1::Devices::Monitoring::AvailableItemSerializer.new(item).as_json }, meta: result[:meta])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
