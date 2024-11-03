class Item < ApplicationRecord
    validates :name, presence: true

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
        where('name ILIKE :query OR category ILIKE :query OR tags ILIKE :query OR current_location ILIKE :query',
              query: "%#{query}%")
    }
end
