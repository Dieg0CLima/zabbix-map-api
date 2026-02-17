class ApplicationController < ActionController::API
  include RackSessionsFix

  private

  def current_organization
    @current_organization ||= begin
      organization_id = params[:organization_id] || params[:org_id]

      if organization_id.present?
        current_user.organizations.find_by(id: organization_id)
      else
        current_user.current_organization
      end
    end
  end

  def current_membership
    return if current_organization.blank?

    @current_membership ||= current_user.membership_for(current_organization.id)
  end

  def ensure_organization_access!
    return if current_organization.present?

    render json: { error: "Organization not found for current user" }, status: :not_found
  end

  def require_editor_or_admin!
    return if current_membership&.role.in?(%w[admin editor])

    render json: { error: "Insufficient permissions" }, status: :forbidden
  end
end
