class Api::V1::Devices::Monitoring::SummaryController < Api::V1::Devices::Monitoring::BaseController
  def show
    summary = Devices::Monitoring::SummaryBuilder.new(profile: monitoring_profile).call
    render_data(data: summary)
  end
end
