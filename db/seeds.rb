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

# Demo records with fixed ids, referenced by the ready-to-copy examples in README.md.
# Keep them in sync with the README when changing anything here.
demo_jane = User.create!(id: 1, first_name: "Jane", last_name: "Doe", email: "jane.doe@borrowbase.test", card_number: "DEMO000001")
demo_john = User.create!(id: 2, first_name: "John", last_name: "Smith", email: "john.smith@borrowbase.test", card_number: "DEMO000002")

# Available, with one returned borrowing in its history
demo_available = Book.create!(id: 1, serial_number: "900001", title: "The Pragmatic Programmer",
                              author1_first_name: "Andrew", author1_last_name: "Hunt",
                              author2_first_name: "David", author2_last_name: "Thomas")
# Currently borrowed by Jane (active borrowing id 3)
demo_borrowed = Book.create!(id: 2, serial_number: "900002", title: "Practical Object-Oriented Design in Ruby",
                             author1_first_name: "Sandi", author1_last_name: "Metz")
# Available, never borrowed — safe to delete
Book.create!(id: 3, serial_number: "900003", title: "Eloquent Ruby",
             author1_first_name: "Russ", author1_last_name: "Olsen")

Borrowing.create!(id: 1, user: demo_john, item: demo_available, borrow_date: 60.days.ago.to_date, return_date: 40.days.ago.to_date)
Borrowing.create!(id: 2, user: demo_jane, item: demo_borrowed, borrow_date: 70.days.ago.to_date, return_date: 45.days.ago.to_date)
Borrowing.create!(id: 3, user: demo_jane, item: demo_borrowed, borrow_date: 10.days.ago.to_date)

# Explicit ids don't advance the sequences, so move them past the demo records
[ User, Item, Borrowing ].each { |model| ActiveRecord::Base.connection.reset_pk_sequence!(model.table_name) }

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
