# frozen_string_literal: true

FactoryBot.define do
  factory :book do
    title { "The Pragmatic Programmer" }
    author1_first_name { "Andrew" }
    author1_last_name { "Hunt" }
  end
end
