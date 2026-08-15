class Users::Admin::Updater
  Result = Struct.new(:user, :membership, keyword_init: true)

  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      @user.update!(user_attributes) if user_attributes.any?
      target_membership&.update!(role: membership_role) if membership_role.present?
    end

    Result.new(user: @user, membership: target_membership)
  end

  private

  def target_membership
    @target_membership ||= begin
      return if membership_role.blank?

      if @params[:organization_id].present?
        membership = @user.memberships.find_by(organization_id: @params[:organization_id])
        raise ArgumentError, "Membership not found for organization" if membership.blank?

        membership
      else
        memberships = @user.memberships.order(:id)
        return memberships.first if memberships.one?

        raise ArgumentError, "organization_id is required when user has memberships in multiple organizations"
      end
    end
  end

  def user_attributes
    attrs = {}
    attrs[:email] = @params[:email].to_s.downcase if @params.key?(:email)
    attrs[:admin] = @params[:admin] unless @params[:admin].nil?
    attrs
  end

  def membership_role
    @params[:membership_role]
  end
end
