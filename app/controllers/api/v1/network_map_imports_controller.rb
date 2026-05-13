require "base64"
require "securerandom"

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
        warnings: Array(result.warnings),
        target_map: {
          action: result.summary[:map],
          network_map_id: result.network_map&.id
        }
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [ { detail: "Record not found" } ])
  rescue Maps::Import::Errors::DomainError => e
    render_domain_error(e)
  end

  def apply
    return enqueue_async_apply if async_apply?

    result = run_import(mode: "apply")

    render_data(
      data: {
        summary: result.summary,
        report: result.report,
        warnings: Array(result.warnings),
        network_map_id: result.network_map.id,
        network_map_name: result.network_map.name
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [ { detail: "Record not found" } ])
  rescue Maps::Import::Errors::DomainError => e
    render_domain_error(e)
  end

  def status
    import_status = Maps::Import::StatusStore.fetch(
      organization: current_organization,
      import_id: params[:import_id].to_s
    )

    unless import_status
      render_errors(status: :not_found, errors: [ { detail: "Import status not found" } ])
      return
    end

    render_data(data: import_status)
  rescue ActiveRecord::RecordNotFound
    render_errors(status: :not_found, errors: [ { detail: "Record not found" } ])
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
      network_map: target_network_map,
      import_id: params[:import_id].to_s.presence
    ).call
  end

  def provider_param
    params[:provider].to_s.strip.presence || "kmz"
  end

  def import_input
    file = input_file
    raw_input = raw_import_input
    Maps::Import::InputGuard.validate!(file: file, raw_input: raw_input, provider: provider_param)

    file.presence || raw_input
  end

  def enqueue_async_apply
    import_id = SecureRandom.uuid
    payload = serialized_input_for_job

    Maps::Import::StatusStore.enqueue!(
      organization: current_organization,
      import_id: import_id,
      provider: provider_param,
      mode: "apply_async",
      requested_by_user_id: current_user.id,
      network_map_id: target_network_map&.id
    )

    Maps::Import::ApplyJob.perform_later(
      organization_id: current_organization.id,
      import_id: import_id,
      provider: provider_param,
      input_payload: payload,
      network_map_id: target_network_map&.id
    )

    render_data(
      data: {
        import_id: import_id,
        status: "queued",
        provider: provider_param,
        poll_url: "/api/v1/network_maps/imports/#{import_id}/status"
      },
      status: :accepted
    )
  end

  def serialized_input_for_job
    file = params[:file]
    raw_input = params[:input]
    Maps::Import::InputGuard.validate!(file: file, raw_input: raw_input, provider: provider_param)

    if file.present?
      file.tempfile.rewind if file.respond_to?(:tempfile) && file.tempfile.respond_to?(:rewind)
      binary = file.read.to_s
      { kind: "binary", data: Base64.strict_encode64(binary) }
    else
      { kind: "text", data: raw_input.to_s }
    end
  end

  def input_file
    params[:file]
  end

  def raw_import_input
    params[:input]
  end

  def async_apply?
    ActiveModel::Type::Boolean.new.cast(params[:async])
  end

  def target_network_map
    map_id = params[:network_map_id].presence
    return nil unless map_id

    current_organization.network_maps.find(map_id)
  end
end
