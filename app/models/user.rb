class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships

  def current_organization
    memberships.includes(:organization).first&.organization
  end

  def membership_for(org_id)
    memberships.find_by(organization_id: org_id)
  end
end
