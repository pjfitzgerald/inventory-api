class Item < ApplicationRecord
    # How long a soft-deleted item stays recoverable. Nothing purges on a
    # timer — `Item.purge_expired!` is called when the recycle bin is listed
    # or emptied, and by the `items:purge_trash` rake task, so the guarantee
    # is "at least this long" rather than "exactly this long".
    TRASH_RETENTION_DAYS = 30

    belongs_to :inventory
    # Who added the item. Access is decided by the inventory, not by this —
    # and it is left behind (null) if the author deletes their account.
    belongs_to :user, optional: true

    validates :name, presence: true

    # Soft delete: `kept` is what every normal read means by "the items".
    scope :kept, -> { where(deleted_at: nil) }
    scope :discarded, -> { where.not(deleted_at: nil) }

      # Convert tags string to array on read
    def tags
        self[:tags]&.split(',')&.map(&:strip)
    end

  # Convert array to string on write
    def tags=(value)
        self[:tags] = value.is_a?(Array) ? value.join(',') : value
    end

  # Search scope
    scope :search, ->(query) {
        where('name ILIKE :query OR category ILIKE :query OR tags ILIKE :query OR current_location ILIKE :query OR sublocation ILIKE :query',
              query: "%#{query}%")
    }

    def discarded?
        deleted_at.present?
    end

    # Move to the recycle bin. Deliberately skips validations and callbacks —
    # an item that fails validation for some unrelated reason must still be
    # deletable.
    def discard!
        update_column(:deleted_at, Time.current)
    end

    def restore!
        update_column(:deleted_at, nil)
    end

    # Drops anything that has sat in the bin past the retention window. Safe to
    # call often; it is a no-op when the bin is empty.
    def self.purge_expired!(scope = all)
        scope.discarded
             .where(deleted_at: ...TRASH_RETENTION_DAYS.days.ago)
             .delete_all
    end
end
