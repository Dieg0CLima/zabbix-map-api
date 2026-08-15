class Api::V1::Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_global_admin!
  before_action :set_user, only: %i[update reset_password]

  def index
    users = User.includes(:memberships).order(:email)

    render json: {
      data: users.map { |user| Users::Admin::PayloadBuilder.new(user: user).call }
    }, status: :ok
  end

  def update
    result = Users::Admin::Updater.new(
      user: @user,
      params: user_update_params
    ).call

    render json: { data: Users::Admin::PayloadBuilder.new(user: result.user).call }, status: :ok
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record, message: "Falha ao atualizar usuário")
  rescue ArgumentError => e
    render json: { code: "INVALID_OPERATION", message: e.message }, status: :unprocessable_entity
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

    render_forbidden_error
  end

  def set_user
    @user = User.find_by(id: params[:id])
    return if @user.present?

    render_not_found_error(message: "User not found")
  end

  def user_update_params
    permitted = params.require(:user).permit(:email, :membership_role, :organization_id).to_h.symbolize_keys

    if params.require(:user).key?(:admin)
      permitted[:admin] = ActiveModel::Type::Boolean.new.cast(params.require(:user)[:admin])
    end

    permitted
  end

  def reset_password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
