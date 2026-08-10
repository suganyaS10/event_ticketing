# run bin/rails db:seed command (or created alongside the database with db:setup).

seed_files = %w[
  events_with_ticket_tiers
].freeze

seed_files.each do |name|
  puts "Seeding #{name}..."
  load Rails.root.join("db/seeds/#{name}.rb")
end
