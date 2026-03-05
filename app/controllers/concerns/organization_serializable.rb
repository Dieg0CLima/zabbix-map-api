module OrganizationSerializable
  extend ActiveSupport::Concern

  private

  def serialize_organization(organization, role)
    return nil if organization.blank?

    {
      id: organization.id,
      name: organization.name,
      slug: organization.slug,
      role: role
    }
  end
end
