class Users::Admin::PayloadBuilder
  def initialize(user:)
    @user = user
  end

  def call
    memberships = @user.memberships.order(:id)

    {
      id: @user.id,
      email: @user.email,
      admin: @user.admin?,
      authentication_source: @user.authentication_source,
      ldap_managed: @user.ldap_managed?,
      memberships: memberships.map { |membership| membership_payload(membership) },
      membership: {
        organization_id: memberships.first&.organization_id,
        role: memberships.first&.role
      }
    }
  end

  private

  def membership_payload(membership)
    {
      organization_id: membership.organization_id,
      role: membership.role
    }
  end
end
