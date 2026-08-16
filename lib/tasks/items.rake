namespace :items do
  desc 'Permanently delete recycle-bin items older than the retention window'
  task purge_trash: :environment do
    before = Item.discarded.count
    purged = Item.purge_expired!
    puts "Purged #{purged} of #{before} binned item(s) " \
         "(retention: #{Item::TRASH_RETENTION_DAYS} days)"
  end
end
