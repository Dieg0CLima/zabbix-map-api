class Api::V1::Users::SessionsController < Devise::SessionsController
  include RackSessionsFix
  include OrganizationSerializable
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    token = request.env["warden-jwt_auth.token"].presence || issue_jwt_for(resource)
    response.set_header("Authorization", "Bearer #{token}") if token.present?

    organization = selected_organization(resource)

    render json: {
      data: {
        id: resource.id,
        email: resource.email,
        org_id: organization&.id,
        organization: serialize_organization(organization, resource.membership_for(organization&.id)&.role),
        admin: resource.admin?
      }
    }, status: :ok
  end

  def respond_to_on_destroy
    if current_user
      render json: { message: "Logged out successfully." }, status: :ok
    else
      render json: { message: "Couldn't find an active session." }, status: :unauthorized
    end
  end

  def selected_organization(user)
    requested_org_id =
      params[:organization_id] ||
      params[:org_id] ||
      params.dig(:user, :organization_id) ||
      params.dig(:user, :org_id)

    if Tenancy::Resolver.single_tenant_mode?
      tenancy_params = ActionController::Parameters.new(
        organization_id: requested_org_id,
        org_id: requested_org_id
      )
      return Tenancy::Resolver.current_organization(user: user, params: tenancy_params)
    end

    return user.current_organization if requested_org_id.blank?
    return Organization.find_by(id: requested_org_id) if user.admin?

    user.organizations.find_by(id: requested_org_id)
  end

  def issue_jwt_for(user)
    scope = Devise::Mapping.find_scope!(user)
    token, = Warden::JWTAuth::UserEncoder.new.call(user, scope, nil)
    token
  rescue StandardError => e
    Rails.logger.warn("JWT issue fallback failed: #{e.class}: #{e.message}")
    nil
  end
end
