# lib/tasks/import.rake
require 'csv'

namespace :import do
  desc "Import items from CSV file"
  task items: :environment do
    filename = Rails.root.join('data', 'initial_item_data.csv')
    counter = 0

    puts "Clearing existing items..."
    Item.destroy_all

    puts "Starting import from #{filename}"

    CSV.foreach(filename, headers: true) do |row|
      # Debug: Print raw row data
      puts "\nProcessing row:"
      puts "Raw row: #{row.to_hash.inspect}\n"
      
      # Convert empty strings to nil
      row_hash = row.to_hash.transform_values { |v| v.presence }
      
      # Debug: Print processed row data
      puts "Processed row_hash: #{row_hash.inspect}"
      
      # The first column in your CSV doesn't have a header, but contains the item name
      name = row[0] # Get the first column value
      
      begin
        item = Item.create!(
          name: name,
          quantity: row_hash['quantity'],
          category: row_hash['category'],
          tags: row_hash['tags'],
          current_location: row_hash['current location'],
          weight: row_hash['weight'],
          owner: row_hash['owner'],
          intended_location: row_hash['intended location'],
          notes: row_hash['notes'],
          location_notes: row_hash['location notes'],
          potential_discard_sell: row_hash["potential sell / discard"]
        )

        if item.persisted?
          counter += 1
          puts "Created item: #{item.name}"
        else
          puts "Failed to create item: #{item.errors.full_messages}"
        end
      rescue => e
        puts "Error creating item: #{e.message}"
      end
    end

    puts "\nImported #{counter} items successfully"
  end
end