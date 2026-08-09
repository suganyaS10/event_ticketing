FactoryBot.define do
  factory :order_item do
    order
    # Pinned to the order's event so the line satisfies OrderItem#tier_belongs_to_order_event.
    ticket_tier { association :ticket_tier, event: order.event }
    quantity { 2 }
    # unit_price_cents is a snapshot taken at purchase time, not a live read of the tier price.
    unit_price_cents { ticket_tier.price_cents }
    total_cents { quantity * unit_price_cents }

    # Simulates a tier whose price moved after this line was written. Use it to assert the
    # order still reflects what the customer agreed to pay.
    trait :price_since_increased do
      after(:create) do |order_item|
        order_item.ticket_tier.update!(price_cents: order_item.unit_price_cents + 1_000)
      end
    end

    # Deliberately invalid: references a tier from a different event.
    trait :for_another_event do
      ticket_tier { association :ticket_tier }
    end
  end
end
