FactoryBot.define do
  factory :customer do
    # email is uniquely indexed, so it must be sequenced to keep the factory collision-free.
    sequence(:email) { |n| "buyer#{n}@example.com" }
    first_name { "Alex" }
    last_name { "Fern" }
    mobile { "+447700900123" }

    # Customer#email is normalised on write; use this to assert the normalisation.
    # Distinct prefix from the default, since both normalise into the same namespace.
    trait :messy_email do
      sequence(:email) { |n| "  MESSY#{n}@Example.COM  " }
    end

    # The brief only requires an email, so everything else is optional.
    trait :minimal do
      first_name { nil }
      last_name { nil }
      mobile { nil }
    end
  end
end
