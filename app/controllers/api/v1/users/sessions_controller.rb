class Api::V1::Users::SessionsController < Devise::SessionsController
  include RackSessionsFix
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

    render json: {
      data: {
        id: resource.id,
        email: resource.email,
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
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :login ])
  end
end
