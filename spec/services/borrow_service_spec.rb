# frozen_string_literal: true

require "rails_helper"

RSpec.describe BorrowService do
  let(:book) { create(:book) }
  let(:user) { create(:user) }

  def call(**overrides)
    described_class.call(user_id: user.id, item_id: book.id, **overrides)
  end

  it "creates a borrowing of the item for the user starting today" do
    borrowing = call

    expect(borrowing).to be_persisted
    expect(borrowing).to have_attributes(item: book, user:, borrow_date: Date.current, return_date: nil)
  end

  it "accepts an item id passed as a string" do
    expect(call(item_id: book.id.to_s)).to be_persisted
  end

  it "borrows an item whose previous borrowing was returned" do
    create(:borrowing, item: book, borrow_date: Date.current - 3.days, return_date: Date.current)

    expect(call).to be_persisted
  end

  it "returns an unsaved borrowing with errors when the item is already borrowed" do
    create(:borrowing, item: book)

    borrowing = call

    expect(borrowing).not_to be_persisted
    expect(borrowing.errors[:item]).to include("is already borrowed")
  end

  it "accepts a user id passed as a string" do
    expect(call(user_id: user.id.to_s)).to be_persisted
  end

  it "returns an unsaved borrowing with errors when the user id is missing" do
    borrowing = call(user_id: nil)

    expect(borrowing).not_to be_persisted
    expect(borrowing.errors[:user]).to include("must exist")
  end

  it "returns an unsaved borrowing with errors when the user does not exist" do
    borrowing = call(user_id: 0)

    expect(borrowing).not_to be_persisted
    expect(borrowing.errors[:user]).to include("must exist")
  end

  it "returns an unsaved borrowing with errors when the item does not exist" do
    borrowing = call(item_id: 0)

    expect(borrowing).not_to be_persisted
    expect(borrowing.errors[:item]).to include("must exist")
  end

  it "returns an unsaved borrowing with errors when the item id is missing" do
    expect(call(item_id: nil).errors[:item]).to include("must exist")
  end

  it "resolves the item through the Item base class as its STI subclass" do
    expect(call.item).to be_a(Book)
  end

  it "borrows only the given item" do
    other = create(:book)

    call

    expect(other.borrowings).to be_empty
  end

  it "returns an unsaved borrowing with errors when called without arguments" do
    borrowing = described_class.call

    expect(borrowing).not_to be_persisted
    expect(borrowing.errors.attribute_names).to contain_exactly(:user, :item)
  end

  it "turns a concurrent insert conflict into an already borrowed error" do
    allow_any_instance_of(Borrowing).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

    borrowing = call

    expect(borrowing).not_to be_persisted
    expect(borrowing.errors[:item]).to include("is already borrowed")
  end
end
