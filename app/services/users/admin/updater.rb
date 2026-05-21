class Users::Admin::Updater
  Result = Struct.new(:user, :membership, keyword_init: true)

  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      @user.update!(user_attributes) if user_attributes.any?
      membership&.update!(role: membership_role) if membership_role.present?
    end

    Result.new(user: @user, membership: membership)
  end

  private

  def membership
    @membership ||= @user.memberships.order(:id).first
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
