class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  AUTHENTICATION_SOURCES = %w[local ldap].freeze

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships

  validates :authentication_source, inclusion: { in: AUTHENTICATION_SOURCES }

  def current_organization
    memberships.includes(:organization).first&.organization
  end

  def membership_for(org_id)
    memberships.find_by(organization_id: org_id)
  end

  def admin?
    admin
  end

  def ldap_managed?
    authentication_source == "ldap"
  end
end
