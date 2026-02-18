class Api::V1::Users::SessionsController < Devise::SessionsController
  include RackSessionsFix
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    # ✅ garante que o header Authorization (se existir) seja exposto
    token = request.env["warden-jwt_auth.token"]
    response.set_header("Authorization", "Bearer #{token}") if token.present?

    organization = selected_organization(resource)

    render json: {
      data: {
        id: resource.id,
        email: resource.email,
        org_id: organization&.id,
        organization: serialized_organization(resource, organization),
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
    requested_org_id = params.dig(:user, :organization_id) || params.dig(:user, :org_id)

    return user.current_organization if requested_org_id.blank?
    return Organization.find_by(id: requested_org_id) if user.admin?

    user.organizations.find_by(id: requested_org_id)
  end

  def serialized_organization(user, organization)
    return nil if organization.blank?

    {
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      role: user.membership_for(organization.id)&.role
    }
  end
end
