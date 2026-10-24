# frozen_string_literal: true

# Sample data for local development. Re-running wipes and recreates all users, books and borrowings.
# Faker is only bundled in development and test, so this file is not meant to run in production.

USERS_COUNT = 20
BOOKS_COUNT = 50
BORROWINGS_COUNT = 200
ACTIVE_BORROWING_RATIO = 0.4

Borrowing.delete_all
Item.delete_all
User.delete_all

Faker::UniqueGenerator.clear

users = Array.new(USERS_COUNT) do |i|
  User.create!(
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    email: Faker::Internet.unique.email,
    card_number: format("CARD%06d", i + 1)
  )
end

books = Array.new(BOOKS_COUNT) do
  co_author = rand < 0.2

  Book.create!(
    title: Faker::Book.unique.title,
    author1_first_name: Faker::Name.first_name,
    author1_last_name: Faker::Name.last_name,
    author2_first_name: (Faker::Name.first_name if co_author),
    author2_last_name: (Faker::Name.last_name if co_author)
  )
end

# Spread borrowings randomly across books, then build each book's history backwards from today
# so periods never overlap and only the most recent borrowing can still be active.
borrowings_per_book = Hash.new(0)
BORROWINGS_COUNT.times { borrowings_per_book[books.sample] += 1 }

borrowings_per_book.each do |book, count|
  cursor = Date.current
  history = []

  if rand < ACTIVE_BORROWING_RATIO
    # Up to 45 days back, so some active borrowings are already overdue
    borrow_date = cursor - rand(0..45).days
    history << { borrow_date:, return_date: nil }
    cursor = borrow_date - rand(1..10).days
  end

  (count - history.size).times do
    return_date = cursor - rand(0..10).days
    borrow_date = return_date - rand(1..40).days
    history << { borrow_date:, return_date: }
    cursor = borrow_date - rand(1..10).days
  end

  history.reverse_each do |attrs|
    Borrowing.create!(user: users.sample, item: book, **attrs)
  end
end

puts "Seeded #{User.count} users, #{Book.count} books, #{Borrowing.count} borrowings " \
     "(#{Borrowing.active.count} active)."
