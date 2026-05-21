class Api::V1::Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_global_admin!
  before_action :set_user, only: %i[update reset_password]

  def index
    users = User.includes(:memberships).order(:email)

    render json: {
      data: users.map { |user| user_payload(user) }
    }, status: :ok
  end

  def update
    result = Users::Admin::Updater.new(
      user: @user,
      params: user_update_params
    ).call

    render json: { data: user_payload(result.user) }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record, message: "Falha ao atualizar usuário")
  end

  def reset_password
    Users::Admin::PasswordReset.new(
      user: @user,
      password: reset_password_params.fetch(:password),
      password_confirmation: reset_password_params.fetch(:password_confirmation)
    ).call

    render json: { data: { id: @user.id, password_reset: true } }, status: :ok
  rescue ArgumentError => e
    render json: { code: "INVALID_OPERATION", message: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record, message: "Falha ao redefinir senha")
  end

  private

  def require_global_admin!
    return if current_user.admin?

    render json: { error: "Insufficient permissions" }, status: :forbidden
  end

  def set_user
    @user = User.find_by(id: params[:id])
    return if @user.present?

    render json: { error: "User not found" }, status: :not_found
  end

  def user_update_params
    permitted = params.require(:user).permit(:email, :membership_role).to_h.symbolize_keys

    if params.require(:user).key?(:admin)
      permitted[:admin] = ActiveModel::Type::Boolean.new.cast(params.require(:user)[:admin])
    end

    permitted
  end

  def reset_password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def user_payload(user)
    memberships = user.memberships.order(:id)

    {
      id: user.id,
      email: user.email,
      admin: user.admin?,
      authentication_source: user.authentication_source,
      ldap_managed: user.ldap_managed?,
      memberships: memberships.map { |membership| { organization_id: membership.organization_id, role: membership.role } },
      membership: {
        organization_id: memberships.first&.organization_id,
        role: memberships.first&.role
      }
    }
  end
end
