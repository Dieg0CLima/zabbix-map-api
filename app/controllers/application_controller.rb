class ApplicationController < ActionController::API
  include RackSessionsFix
  after_action :refresh_jwt_session!

  private

  def refresh_jwt_session!
    return unless current_user.present?
    return unless request.path.start_with?("/api/v1/")
    return if request.path.in?([ "/api/v1/users/sign_in", "/api/v1/users/sign_out", "/api/v1/login", "/api/v1/logout" ])

    scope = Devise::Mapping.find_scope!(current_user)
    token, = Warden::JWTAuth::UserEncoder.new.call(current_user, scope, nil)
    response.set_header("Authorization", "Bearer #{token}")
  rescue StandardError => e
    Rails.logger.debug("JWT refresh skipped: #{e.class}: #{e.message}")
  end

  def current_organization
    @current_organization ||= Tenancy::Resolver.current_organization(user: current_user, params: params)
  end

  def current_membership
    return if current_organization.blank?

    @current_membership ||= current_user.membership_for(current_organization.id)
  end

  def ensure_organization_access!
    if Tenancy::Resolver.single_tenant_mode?
      return if current_organization.present?

      render json: { error: "Organization not configured for this installation" }, status: :service_unavailable
      return
    end

    return if current_user.admin? && params[:organization_id].blank? && params[:org_id].blank?
    return if current_organization.present?

    render json: { error: "Organization not found for current user" }, status: :not_found
  end

  def admin_without_organization_context?
    current_user.admin? && current_organization.blank?
  end

  def ensure_organization_context_for_creation!
    return false unless admin_without_organization_context?

    render json: { error: "organization_id is required for this action" }, status: :bad_request
    true
  end

  def require_editor_or_admin!
    return if current_user.admin?
    return if current_membership&.role.in?(%w[admin editor])

    render json: { error: "Insufficient permissions" }, status: :forbidden
  end

  def render_validation_error(record_or_details, message: "Payload inválido")
    details = if record_or_details.respond_to?(:errors)
      record_or_details.errors.to_hash(true)
    else
      record_or_details
    end

    render json: {
      code: "VALIDATION_ERROR",
      message:,
      details:
    }, status: :unprocessable_entity
  end
end
