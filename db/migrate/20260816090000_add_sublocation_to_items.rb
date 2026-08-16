# An optional second level of location — "shelf 3" under "garage", "side
# pocket" under "camera bag". Kept as a plain string alongside
# `current_location` rather than modelled as a relation: locations themselves
# are still free text (turning them into their own entity is a separate
# backlog item), so a sublocation column is the smallest thing that matches
# how the field is actually used today.
class AddSublocationToItems < ActiveRecord::Migration[7.0]
  def change
    add_column :items, :sublocation, :string
  end
end
