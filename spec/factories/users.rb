# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:card_number) { |n| format("CARD%06d", n) }
  end
end
