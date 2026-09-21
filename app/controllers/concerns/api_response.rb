module ApiResponse
  extend ActiveSupport::Concern

  private

  def render_data(data:, status: :ok, meta: {})
    render json: { data:, meta:, errors: [] }, status:
  end

  def render_errors(errors:, status: :unprocessable_entity, meta: {}, code: nil, message: nil, details: nil)
    normalized_errors = Array(errors).map do |error|
      error.is_a?(Hash) ? error : { detail: error.to_s }
    end

    code ||= status_to_error_code(status) || normalized_errors.first&.dig(:code) || "ERROR"
    message ||= normalized_errors.first&.dig(:detail) || "Error"

    payload = {
      data: nil,
      meta:,
      errors: normalized_errors,
      code:,
      message: message,
      error: message
    }
    payload[:details] = details unless details.nil?

    render json: payload, status:
  end

  def render_record_errors(record, status: :unprocessable_entity)
    render_errors(
      status:,
      errors: record.errors.map do |error|
        { source: error.attribute, detail: error.message }
      end
    )
  end

  def status_to_error_code(status)
    {
      forbidden: "FORBIDDEN",
      not_found: "NOT_FOUND",
      service_unavailable: "SERVICE_UNAVAILABLE",
      unauthorized: "UNAUTHORIZED",
      unprocessable_entity: "VALIDATION_ERROR"
    }[status]
  end
end
