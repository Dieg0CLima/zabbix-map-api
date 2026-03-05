class Api::V1::Users::RegistrationsController < Devise::RegistrationsController
  include RackSessionsFix
  respond_to :json

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

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :organization_name, :organization_id)
  end

  def registration_payload(result)
    {
      id: result.user.id,
      email: result.user.email,
      organization: organization_payload(result.organization, result.membership)
    }
  end

  def organization_payload(organization, membership)
    return nil if organization.blank?

    {
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      role: membership&.role
    }
  end
end
