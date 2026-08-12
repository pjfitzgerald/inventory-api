# A container for items that one or more users can reach. Every user has
# exactly one personal inventory (created with the account, undeletable);
# any further inventories are shared by inviting other accounts as members.
class Inventory < ApplicationRecord
  belongs_to :owner, class_name: 'User'

  has_many :inventory_memberships, dependent: :destroy
  has_many :members, through: :inventory_memberships, source: :user
  has_many :items, dependent: :destroy

  validates :name, presence: true, length: { maximum: 60 }
  validate :personal_inventory_is_unique_per_owner

  scope :personal, -> { where(personal: true) }
  scope :shared, -> { where(personal: false) }

  # The owner's membership is created alongside the inventory — ownership is
  # expressed as a membership row so every access check has one shape.
  after_create :add_owner_as_member

  def membership_for(user)
    inventory_memberships.find_by(user_id: user&.id)
  end

  def role_for(user)
    membership_for(user)&.role
  end

  private

  def add_owner_as_member
    inventory_memberships.create!(user: owner, role: InventoryMembership::OWNER)
  end

  def personal_inventory_is_unique_per_owner
    return unless personal? && owner_id.present?

    clash = Inventory.personal.where(owner_id: owner_id).where.not(id: id).exists?
    errors.add(:personal, 'inventory already exists for this user') if clash
  end
end
