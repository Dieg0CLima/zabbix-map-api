class Api::V1::Users::RegistrationsController < Devise::RegistrationsController
  include RackSessionsFix
  include OrganizationSerializable
  respond_to :json

  # Public sign up is off unless ALLOW_PUBLIC_SIGNUP is exactly "true". Prepended so it
  # runs before anything else Devise does (including require_no_authentication).
  prepend_before_action :ensure_public_signup_enabled!, only: %i[new create cancel]
  before_action :reject_organization_id!, only: :create

  def create
    result = Users::Register.new(
      user_params: sign_up_params.slice(:email, :password, :password_confirmation),
      organization_name: sign_up_params[:organization_name],
      organization_id: sign_up_params[:organization_id]
    ).call

    sign_up(resource_name, result.user)
    render json: { data: registration_payload(result) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      code: "VALIDATION_ERROR",
      message: "Registration failed",
      details: e.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  private

  def public_signup_enabled?
    ENV["ALLOW_PUBLIC_SIGNUP"].to_s.strip.casecmp?("true")
  end

  def ensure_public_signup_enabled!
    return if public_signup_enabled?

    render_not_found_error(message: "Not found")
  end

  # Public sign up never attaches the new user to an existing organization.
  def reject_organization_id!
    user_params = params[:user]
    return unless user_params.is_a?(ActionController::Parameters) && user_params[:organization_id].present?

    render_api_error(
      code: "VALIDATION_ERROR",
      message: "organization_id is not accepted on sign up",
      status: :unprocessable_entity
    )
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :organization_name, :organization_id)
  end

  def registration_payload(result)
    {
      id: result.user.id,
      email: result.user.email,
      organization: serialize_organization(result.organization, result.membership&.role)
    }
  end
end
