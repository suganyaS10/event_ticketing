# Seeds events and the ticket tiers they sell.
# Idempotency: the 5 events below would be restored to the state below

riverside_start = 3.weeks.from_now.change(hour: 18, min: 0)
harbour_start   = 10.days.from_now.change(hour: 20, min: 0)
winter_start    = 8.weeks.from_now.change(hour: 17, min: 0)
summer_start    = 6.weeks.from_now.change(hour: 14, min: 0)
warehouse_start = 3.weeks.ago.change(hour: 22, min: 0)

events = [
  {
    name: "Riverside Night Market - Happy path",
    venue: "Bankside Yard, London",
    short_description: "Street food, live sets and a late bar beside the Thames.",
    description: "Twenty independent kitchens, three stages and a riverside bar. " \
                 "Doors at 6pm, last entry 9pm. Under-12s must be accompanied.",
    status: :published,
    start_time: riverside_start,
    end_time: riverside_start + 5.hours,
    ticket_tiers: [
      {
        name: "General Admission",
        price_cents: 2_500,
        quantity_total: 100,
        quantity_sold: 40
      },
      {
        name: "VIP",
        price_cents: 7_500,
        quantity_total: 20,
        quantity_sold: 5,
        perks: "Priority entry, dedicated bar and cloakroom included."
      },
      {
        name: "Child (under 12)",
        price_cents: 1_000,
        quantity_total: 50,
        quantity_sold: 0
      }
    ]
  },

  {
    name: "Harbour Jazz Session - GA with exactly 1 ticket available",
    venue: "The Old Custom House, Bristol",
    short_description: "An intimate late set from the Harbour Quartet.",
    description: "Two sets with an interval. Seating is unreserved except in the balcony.",
    status: :published,
    start_time: harbour_start,
    end_time: harbour_start + 3.hours,
    ticket_tiers: [
      {
        name: "General Admission",
        price_cents: 1_800,
        quantity_total: 60,
        quantity_sold: 59
      },
      {
        name: "Balcony",
        price_cents: 3_000,
        quantity_total: 20,
        quantity_sold: 20,
        perks: "Reserved seating with a view over the harbour."
      }
    ]
  },
  {
    name: "Winter Light Festival - Early bird ticket window closed",
    venue: "Kelvingrove Park, Glasgow",
    short_description: "A mile of light installations across the park.",
    description: "Timed entry every 30 minutes. The route is step-free throughout.",
    status: :published,
    start_time: winter_start,
    end_time: winter_start + 6.hours,
    ticket_tiers: [
      {
        name: "Early Bird",
        price_cents: 1_500,
        quantity_total: 200,
        quantity_sold: 120,
        sale_starts_at: 60.days.ago,
        sale_ends_at: 1.day.ago
      },
      {
        name: "Standard",
        price_cents: 2_200,
        quantity_total: 300,
        quantity_sold: 35,
        sale_starts_at: 1.day.ago,
        sale_ends_at: winter_start
      }
    ]
  },

  {
    name: "Summer Sessions - draft event",
    venue: "Sefton Park, Liverpool",
    short_description: "Line-up still under wraps.",
    description: "Details to be announced.",
    status: :draft,
    start_time: summer_start,
    end_time: summer_start + 8.hours,
    ticket_tiers: [
      {
        name: "General Admission",
        price_cents: 2_000,
        quantity_total: 40,
        quantity_sold: 0
      }
    ]
  },

  {
    name: "Spring Warehouse Party - past event",
    venue: "Unit 9, Ancoats, Manchester",
    short_description: "All-night warehouse session.",
    description: "This event has already taken place.",
    status: :published,
    start_time: warehouse_start,
    end_time: warehouse_start + 6.hours,
    ticket_tiers: [
      {
        name: "General Admission",
        price_cents: 2_000,
        quantity_total: 80,
        quantity_sold: 12
      }
    ]
  }
]

events.each do |attributes|
  event = Event.find_or_initialize_by(name: attributes[:name])
  event.assign_attributes(attributes.except(:name, :ticket_tiers))
  event.save!

  attributes.fetch(:ticket_tiers).each do |tier_attributes|
    tier = event.ticket_tiers.find_or_initialize_by(name: tier_attributes[:name])
    tier.assign_attributes(tier_attributes.except(:name))
    tier.save!
  end

  puts "  #{event.name} (#{event.status}) — #{event.ticket_tiers.count} tiers"
end
