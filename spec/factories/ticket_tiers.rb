FactoryBot.define do
  factory :ticket_tier do
    event
    # [event_id, name] is uniquely indexed, so the default name is sequenced to keep
    # create_list(:ticket_tier, 3, event: event) safe. Named traits override it.
    sequence(:name) { |n| "General Admission #{n}" }
    price_cents { 2_500 }
    currency { "GBP" }
    quantity_total { 100 }
    quantity_sold { 0 }
    perks { "Water bottle, a brownie" }

    trait :vip do
      name { "VIP" }
      price_cents { 7_500 }
      quantity_total { 20 }
      perks { "Priority entry, dedicated bar, cloakroom included." }
    end

    # Inventory states. The DB check constraint allows quantity_sold == quantity_total.
    trait :sold_out do
      quantity_sold { quantity_total }
    end

    trait :one_left do
      quantity_sold { quantity_total - 1 }
    end

    trait :tiny do
      quantity_total { 1 }
      quantity_sold { 0 }
    end

    # Sales windows, for whichever of these the purchase path ends up enforcing.
    trait :on_sale do
      sale_starts_at { 1.day.ago }
      sale_ends_at { 30.days.from_now }
    end

    trait :not_yet_on_sale do
      sale_starts_at { 1.day.from_now }
      sale_ends_at { 30.days.from_now }
    end

    trait :sales_ended do
      sale_starts_at { 30.days.ago }
      sale_ends_at { 1.day.ago }
    end
  end
end
