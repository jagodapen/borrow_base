# frozen_string_literal: true

FactoryBot.define do
  factory :borrowing do
    user
    item factory: :book
    borrow_date { Date.current }
  end
end
