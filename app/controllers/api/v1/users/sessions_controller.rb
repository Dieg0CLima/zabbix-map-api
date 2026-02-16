class Api::V1::Users::SessionsController < Devise::SessionsController
  include RackSessionsFix
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    # ✅ garante que o header Authorization (se existir) seja exposto
    token = request.env["warden-jwt_auth.token"]
    response.set_header("Authorization", "Bearer #{token}") if token.present?

    render json: {
      data: {
        id: resource.id,
        email: resource.email
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
end
