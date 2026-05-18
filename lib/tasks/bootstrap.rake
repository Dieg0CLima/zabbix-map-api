namespace :bootstrap do
  desc "Ensure global master user using MASTER_USER_EMAIL and MASTER_USER_PASSWORD"
  task ensure_master_user: :environment do
    email = ENV["MASTER_USER_EMAIL"]
    password = ENV["MASTER_USER_PASSWORD"]

    result = Bootstrap::EnsureMasterUser.new(email:, password:).call

    action = result.created ? "created" : "updated"
    puts "[bootstrap] Master user #{action}: #{result.email}"
  end
end
