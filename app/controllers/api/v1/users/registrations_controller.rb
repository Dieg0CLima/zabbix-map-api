class Api::V1::Users::RegistrationsController < Devise::RegistrationsController
  include RackSessionsFix
  include OrganizationSerializable
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
      organization: serialize_organization(result.organization, result.membership&.role)
    }
  end

end
