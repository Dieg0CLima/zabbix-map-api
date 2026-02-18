class Api::V1::Users::RegistrationsController < Devise::RegistrationsController
  include RackSessionsFix
  respond_to :json

  def create
    build_resource(sign_up_params)

    ActiveRecord::Base.transaction do
      resource.save!
      ensure_registration_organization!(resource)
    end

    sign_up(resource_name, resource)
    respond_with resource, location: after_sign_up_path_for(resource)
  rescue ActiveRecord::RecordInvalid
    clean_up_passwords resource
    set_minimum_password_length

    render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
  end

  private

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :organization_name, :organization_id)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password)
  end

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render json: {
        data: {
          id: resource.id,
          email: resource.email,
          organization: serialized_organization(resource)
        }
      }, status: :created
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def ensure_registration_organization!(user)
    org = selected_organization
    return if org.blank?

    Membership.find_or_create_by!(user: user, organization: org) do |membership|
      membership.role = "admin"
    end
  end

  def selected_organization
    return Organization.find_by(id: sign_up_params[:organization_id]) if sign_up_params[:organization_id].present?
    return if sign_up_params[:organization_name].blank?

    Organization.create!(name: sign_up_params[:organization_name])
  end

  def serialized_organization(user)
    organization = user.current_organization
    return nil if organization.blank?

    {
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      role: user.membership_for(organization.id)&.role
    }
  end
end
