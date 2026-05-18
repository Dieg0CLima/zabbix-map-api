class Api::V1::Users::SessionsController < Devise::SessionsController
  include RackSessionsFix
  include OrganizationSerializable
  respond_to :json
  before_action :configure_sign_in_params, only: :create

  def create
    ldap_config = Auth::Ldap::Config.current
    return super unless ldap_config.enabled?

    login = params.dig(:user, :email).presence || params.dig(:user, :login).to_s
    password = params.dig(:user, :password).to_s

    auth_result = Auth::Ldap::Authenticator.new(config: ldap_config).call(login:, password:)

    if auth_result.success?
      user = Auth::Ldap::UserResolver.new(config: ldap_config).call(
        email: auth_result.email,
        login: auth_result.login.presence || login,
        name: auth_result.name
      )
      return render_invalid_login unless user

      sign_in(resource_name, user)
      return respond_with(user)
    end

    return super if ldap_config.fallback_to_database_auth?

    render_invalid_login
  end

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

  def respond_to_on_destroy(*)
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

  def render_invalid_login
    render json: { error: "Invalid email or password" }, status: :unauthorized
  end

  def configure_sign_in_params
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :organization_id, :org_id, :login ])
  end
end
