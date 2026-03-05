class Users::Register
  Result = Struct.new(:user, :organization, :membership, keyword_init: true)

  def initialize(user_params:, organization_name: nil, organization_id: nil)
    @user_params = user_params
    @organization_name = organization_name
    @organization_id = organization_id
  end

  def call
    user = User.new(@user_params)

    ActiveRecord::Base.transaction do
      user.save!
      organization = resolve_organization
      membership = create_membership!(user, organization) if organization.present?

      Result.new(user:, organization:, membership:)
    end
  end

  private

  def resolve_organization
    if @organization_id.present?
      Organization.find_by(id: @organization_id)
    elsif @organization_name.present?
      Organization.create!(name: @organization_name)
    end
  end

  def create_membership!(user, organization)
    Membership.find_or_create_by!(user:, organization:) do |membership|
      membership.role = "admin"
    end
  end
end
