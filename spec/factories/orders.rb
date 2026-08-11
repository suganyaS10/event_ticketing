FactoryBot.define do
  factory :order do
    event
    customer
    total_cents { 0 }

    trait :with_items do
      transient do
        items_count { 1 }
        quantity { 2 }
      end

      after(:create) do |order, evaluator|
        evaluator.items_count.times do
          create(:order_item, order: order, quantity: evaluator.quantity)
        end
        order.update!(total_cents: order.order_items.reload.sum(:total_cents))
      end
    end

    trait :with_mixed_tiers do
      after(:create) do |order|
        ga = create(:ticket_tier, event: order.event, name: "General Admission")
        vip = create(:ticket_tier, :vip, event: order.event)
        create(:order_item, order: order, ticket_tier: ga, quantity: 2)
        create(:order_item, order: order, ticket_tier: vip, quantity: 1)
        order.update!(total_cents: order.order_items.reload.sum(:total_cents))
      end
    end
  end
end
