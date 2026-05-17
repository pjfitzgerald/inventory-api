require 'csv'

# Seeded items belong to a single owner account. Override the credentials
# with SEED_OWNER_EMAIL / SEED_OWNER_PASSWORD; the defaults are for local dev.
owner_email = ENV.fetch('SEED_OWNER_EMAIL', 'owner@example.com').strip.downcase
owner = User.find_or_initialize_by(email: owner_email)
if owner.new_record?
  owner.password = ENV.fetch('SEED_OWNER_PASSWORD', 'changeme123')
  owner.name = 'Inventory Owner'
  owner.email_verified_at = Time.current
  owner.save!
  puts "Created owner user #{owner.email}"
else
  puts "Using existing owner user #{owner.email}"
end

# Clear this owner's existing items
puts "Clearing existing items for #{owner.email}..."
owner.items.destroy_all

# Load seed data from CSV
csv_path = Rails.root.join('data', 'seed-data.csv')
puts "Loading items from #{csv_path}..."

# Map status values from CSV to database values
def convert_status(csv_value)
  return 'Keep' if csv_value.blank?

  case csv_value.to_s.downcase.strip
  when 'yes', 'sell'
    'Sell'
  when 'discard'
    'Discard'
  else
    'Keep'
  end
end

items_created = 0
items_skipped = 0

CSV.foreach(csv_path, headers: true, liberal_parsing: true) do |row|
  # Skip empty rows (where item name is blank)
  if row['item'].blank?
    items_skipped += 1
    next
  end

  owner.items.create!(
    name: row['item'],
    quantity: row['quantity'].presence&.to_i,
    category: row['category'].presence,
    tags: row['tags'].presence,
    current_location: row['current location'].presence,
    weight: row['weight'].presence&.to_d,
    owner: row['owner'].presence,
    intended_location: row['intended location'].presence,
    notes: row['notes'].presence,
    location_notes: row['location notes'].presence,
    status: convert_status(row['potential sell / discard'])
  )
  items_created += 1
end

puts "Seeding complete!"
puts "  Items created: #{items_created}"
puts "  Empty rows skipped: #{items_skipped}"
