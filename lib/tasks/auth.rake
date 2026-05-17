namespace :auth do
  desc "Create or update a user's password and mark them verified. " \
       "Usage: rails 'auth:set_password[email,password]'"
  task :set_password, %i[email password] => :environment do |_task, args|
    email = args[:email].to_s.strip.downcase
    password = args[:password].to_s

    if email.empty? || password.empty?
      abort "Usage: rails 'auth:set_password[email,password]'"
    end

    user = User.find_or_initialize_by(email: email)
    created = user.new_record?
    user.password = password
    user.email_verified_at ||= Time.current
    user.email_verification_token = nil

    if user.save
      puts "#{created ? 'Created' : 'Updated'} #{user.email} (verified)"
    else
      abort "Failed: #{user.errors.full_messages.join(', ')}"
    end
  end
end
