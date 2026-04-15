class Api::V1::Devices::Monitoring::ItemsController < Api::V1::Devices::Monitoring::BaseController
  before_action :set_item, only: %i[update destroy]

  def index
    items      = monitoring_profile&.device_monitoring_items&.includes(:zabbix_item) || []
    live_values = fetch_live_history(items)
    render_data(data: items.map { |item|
      Api::V1::Devices::Monitoring::ItemSerializer.new(item, live_values: live_values).as_json
    })
  end

  def create
    item = Devices::Monitoring::ItemCreator.new(profile: monitoring_profile, params: item_params).call
    live_values = fetch_live_history([ item ])
    render_data(
      data:   Api::V1::Devices::Monitoring::ItemSerializer.new(item, live_values: live_values).as_json,
      status: :created
    )
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def update
    item = Devices::Monitoring::ItemUpdater.new(item: @item, params: item_params).call
    live_values = fetch_live_history([ item ])
    render_data(data: Api::V1::Devices::Monitoring::ItemSerializer.new(item, live_values: live_values).as_json)
  rescue ActiveRecord::RecordInvalid => e
    render_record_errors(e.record)
  end

  def destroy
    @item.destroy!
    render_data(data: nil)
  rescue ActiveRecord::RecordNotDestroyed
    render_record_errors(@item)
  end

  private

  def set_item
    profile = monitoring_profile
    raise ActiveRecord::RecordNotFound unless profile

    @item = profile.device_monitoring_items.find(params[:id])
  end

  def item_params
    params.require(:monitoring_item).permit(:zabbix_item_id, :alias, :category, :subcategory, :usage, :display_priority, :map_visibility, :is_primary_metric, :is_health_metric, metadata: {})
  end

  def fetch_live_history(items)
    zabbix_items = items.filter_map(&:zabbix_item)
    Zabbix::LiveValuesFetcher.new(items: zabbix_items).call
  end
end
