FactoryBot.define do
  factory :event do
    sequence(:name) { |n| "Night Market ##{n}" }
    venue { "The Lexington, London" }
    short_description { "An evening of live music and street food." }
    description { "Doors at 7pm. Over-18s only. Card payments at the bar." }
    start_time { 2.weeks.from_now.change(hour: 19, min: 0) }
    end_time { start_time + 3.hours }
    status { :published }

    # :draft and :published traits are auto-defined by factory_bot from the enum on Event.

    trait :past do
      start_time { 2.weeks.ago.change(hour: 19, min: 0) }
      end_time { start_time + 3.hours }
    end

    # end_time is optional; useful for exercising the allow_nil branch of the comparison validation.
    trait :open_ended do
      end_time { nil }
    end

    # Gives the event a realistic multi-tier lineup. Pass `tiers:` to override.
    trait :with_tiers do
      transient do
        tiers { { "General Admission" => 2_500, "VIP" => 7_500 } }
      end

      after(:create) do |event, evaluator|
        evaluator.tiers.each do |name, price_cents|
          create(:ticket_tier, event: event, name: name, price_cents: price_cents)
        end
      end
    end
  end
end
