module ApiResponse
  extend ActiveSupport::Concern

  private

  def render_data(data:, status: :ok, meta: {})
    render json: { data:, meta:, errors: [] }, status:
  end

  def render_errors(errors:, status: :unprocessable_entity, meta: {})
    normalized_errors = Array(errors).map do |error|
      error.is_a?(Hash) ? error : { detail: error.to_s }
    end

    render json: { data: nil, meta:, errors: normalized_errors }, status:
  end

  def render_record_errors(record, status: :unprocessable_entity)
    render_errors(
      status:,
      errors: record.errors.map do |error|
        { source: error.attribute, detail: error.message }
      end
    )
  end
end
