class Api::V1::NetworkMapImportsController < Api::V1::BaseController
  include DomainErrorHandler

  before_action :require_editor_or_admin!

  def preview
    result = run_import(mode: "preview")

    render_data(
      data: {
        summary: result.summary,
        report: result.report,
        normalized_payload: result.normalized_payload,
        warnings: [],
        target_map: {
          action: result.summary[:map],
          network_map_id: result.network_map&.id
        }
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [{ detail: "Record not found" }])
  rescue Maps::Import::Errors::DomainError => e
    render_domain_error(e)
  end

  def apply
    result = run_import(mode: "apply")

    render_data(
      data: {
        summary: result.summary,
        report: result.report,
        network_map_id: result.network_map.id,
        network_map_name: result.network_map.name
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [{ detail: "Record not found" }])
  rescue Maps::Import::Errors::DomainError => e
    render_domain_error(e)
  end

  private

  def run_import(mode:)
    Maps::Import::Run.new(
      organization: current_organization,
      provider: provider_param,
      input: import_input,
      mode: mode,
      network_map: target_network_map
    ).call
  end

  def provider_param
    params[:provider].to_s.strip.presence || "kmz"
  end

  def import_input
    input = params[:file] || params[:input]
    return input if input.present?

    raise Maps::Import::Errors::DomainError.new(
      code: "import_missing_input",
      message: "Import input is required",
      details: { accepted: %w[file input] }
    )
  end

  def target_network_map
    map_id = params[:network_map_id].presence
    return nil unless map_id

    current_organization.network_maps.find(map_id)
  end
end
