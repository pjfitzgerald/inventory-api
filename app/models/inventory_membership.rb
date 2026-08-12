# Joins a user to an inventory with a role. Roles are ordered: an owner can do
# anything an editor can, an editor anything a viewer can.
class InventoryMembership < ApplicationRecord
  OWNER  = 'owner'
  EDITOR = 'editor'
  VIEWER = 'viewer'

  ROLES = [OWNER, EDITOR, VIEWER].freeze
  # Roles that can be handed out when inviting or changing a member. Ownership
  # is not transferable through this route — there is exactly one owner, set
  # when the inventory is created.
  ASSIGNABLE_ROLES = [EDITOR, VIEWER].freeze

  belongs_to :inventory
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :inventory_id,
                                    message: 'is already a member of this inventory' }

  def owner?  = role == OWNER
  def viewer? = role == VIEWER

  # Everything except a viewer may add, change, and delete items.
  def can_edit_items? = !viewer?

  # Only the owner may rename or delete the inventory and manage its members.
  def can_manage? = owner?
end
