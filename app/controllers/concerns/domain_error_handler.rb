module DomainErrorHandler
  extend ActiveSupport::Concern

  private

  def render_domain_error(error)
    render json: {
      code: error.code,
      message: error.message,
      details: error.details
    }, status: :unprocessable_entity
  end

  def render_service_unavailable(message:, details: nil)
    render json: {
      code: "SERVICE_UNAVAILABLE",
      message:,
      details:
    }, status: :service_unavailable
  end
end
