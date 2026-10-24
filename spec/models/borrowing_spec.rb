# frozen_string_literal: true

require "rails_helper"

RSpec.describe Borrowing, type: :model do
  subject(:borrowing) { build(:borrowing) }

  it { is_expected.to be_valid }

  it "sets BORROW_TIME_LIMIT to 30 days" do
    expect(described_class::BORROW_TIME_LIMIT).to eq(30.days)
  end

  describe "associations" do
    it "is invalid without a user" do
      borrowing.user = nil
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:user]).to include("must exist")
    end

    it "is invalid without an item" do
      borrowing.item = nil
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:item]).to include("must exist")
    end

    it "belongs to a polymorphic item" do
      book = create(:book)
      borrowing = create(:borrowing, item: book)

      expect(borrowing.reload.item).to eq(book)
      expect(borrowing.item_type).to eq("Book")
    end
  end

  describe "validations" do
    it "is invalid without borrow_date on update" do
      borrowing.save!
      borrowing.borrow_date = nil
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:borrow_date]).to include("can't be blank")
    end

    it "is invalid without due_date on update" do
      borrowing.save!
      borrowing.borrow_date = nil
      borrowing.due_date = nil
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:due_date]).to include("can't be blank")
    end

    it "is invalid when only due_date is set to nil on update" do
      borrowing.save!
      borrowing.due_date = nil
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:due_date]).to include("can't be blank")
    end

    it "is valid without return_date" do
      borrowing.return_date = nil
      expect(borrowing).to be_valid
    end
  end

  describe "borrow_date" do
    it "defaults to today when not passed" do
      borrowing.borrow_date = nil
      borrowing.save!
      expect(borrowing.reload.borrow_date).to eq(Date.current)
    end

    it "calculates due_date from the default" do
      borrowing.borrow_date = nil
      borrowing.valid?
      expect(borrowing.due_date).to eq(Date.current + described_class::BORROW_TIME_LIMIT)
    end

    it "keeps a passed value" do
      borrowing.borrow_date = Date.new(2026, 10, 1)
      borrowing.save!
      expect(borrowing.reload.borrow_date).to eq(Date.new(2026, 10, 1))
    end

    it "is valid when today" do
      borrowing.borrow_date = Date.current
      expect(borrowing).to be_valid
    end

    it "is valid when in the past" do
      borrowing.borrow_date = Date.current - 1.day
      expect(borrowing).to be_valid
    end

    it "is invalid when tomorrow" do
      borrowing.borrow_date = Date.current + 1.day
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:borrow_date]).to include("cannot be in the future")
    end

    it "is invalid when in the far future" do
      borrowing.borrow_date = Date.current + 1.year
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:borrow_date]).to include("cannot be in the future")
    end

    it "is invalid when changed to a future date on update" do
      borrowing.save!
      borrowing.borrow_date = Date.current + 1.day
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:borrow_date]).to include("cannot be in the future")
    end

    it "does not add the future error when blank" do
      borrowing.save!
      borrowing.borrow_date = nil
      borrowing.valid?
      expect(borrowing.errors[:borrow_date]).not_to include("cannot be in the future")
    end
  end

  describe "item availability" do
    let(:book) { create(:book) }

    subject(:borrowing) { build(:borrowing, item: book) }

    it "is valid when the item has never been borrowed" do
      expect(borrowing).to be_valid
    end

    it "is invalid when the item has an unreturned borrowing within its limit" do
      create(:borrowing, item: book)
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:item]).to include("is already borrowed")
    end

    it "is invalid when the existing borrowing's limit date is tomorrow" do
      create(:borrowing, item: book, borrow_date: Date.current - described_class::BORROW_TIME_LIMIT + 1.day)
      expect(borrowing).not_to be_valid
    end

    it "is valid when the existing borrowing has been returned" do
      create(:borrowing, item: book, return_date: Date.current)
      expect(borrowing).to be_valid
    end

    it "is invalid when the existing borrowing's limit date is today" do
      create(:borrowing, item: book, borrow_date: Date.current - described_class::BORROW_TIME_LIMIT)
      expect(borrowing).not_to be_valid
    end

    it "is invalid when the existing borrowing is overdue" do
      create(:borrowing, item: book, borrow_date: Date.current - described_class::BORROW_TIME_LIMIT - 1.day)
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:item]).to include("is already borrowed")
    end

    it "is valid when another item is borrowed" do
      create(:borrowing)
      expect(borrowing).to be_valid
    end

    it "is valid when an item of another type shares the same id" do
      create(:borrowing, item: book).update_columns(item_type: "Other")
      expect(borrowing).to be_valid
    end

    it "does not block updating the active borrowing itself" do
      active = create(:borrowing, item: book)
      expect(active.update(return_date: Date.current)).to be(true)
    end
  end

  describe "active item uniqueness index" do
    let(:book) { create(:book) }

    # Skips model validations (and before_validation callbacks), so dates are set explicitly
    def insert_borrowing(**attrs)
      build(:borrowing, item: book, borrow_date: Date.current, due_date: Date.current + described_class::BORROW_TIME_LIMIT, **attrs)
        .save!(validate: false)
    end

    before { create(:borrowing, item: book) }

    it "rejects a second active borrowing of the same item when validation is bypassed" do
      expect { insert_borrowing }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a returned borrowing of the same item" do
      expect { insert_borrowing(return_date: Date.current) }
        .not_to raise_error
    end

    it "allows a new active borrowing once the previous one is returned" do
      book.borrowings.first.update!(return_date: Date.current)
      expect { create(:borrowing, item: book) }.not_to raise_error
    end

    it "allows an active borrowing of an item of another type with the same id" do
      expect { insert_borrowing(item_type: "Other") }
        .not_to raise_error
    end
  end

  describe "reference immutability" do
    let!(:borrowing) { create(:borrowing) }

    it "is invalid when user is changed on update" do
      borrowing.user = create(:user)
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:user]).to include("cannot be changed")
    end

    it "is invalid when item is changed to another item of the same type" do
      borrowing.item = create(:book)
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:item]).to include("cannot be changed")
    end

    it "is invalid when only item_type is changed" do
      borrowing.item_type = "User"
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:item]).to include("cannot be changed")
    end

    it "does not persist the changed references" do
      original_user = borrowing.user
      original_item = borrowing.item
      borrowing.update(user: create(:user), item: create(:book))

      borrowing.reload
      expect(borrowing.user).to eq(original_user)
      expect(borrowing.item).to eq(original_item)
    end

    it "is valid when references are reassigned to the same records" do
      borrowing.user = User.find(borrowing.user_id)
      borrowing.item = Book.find(borrowing.item_id)
      expect(borrowing).to be_valid
    end

    it "allows updating other attributes" do
      expect(borrowing.update(return_date: Date.current)).to be(true)
    end

    it "allows setting references on create" do
      expect(build(:borrowing, user: create(:user), item: create(:book))).to be_valid
    end
  end

  describe ".active" do
    it "includes unreturned borrowings within their limit" do
      borrowing = create(:borrowing)
      expect(described_class.active).to contain_exactly(borrowing)
    end

    it "includes overdue unreturned borrowings" do
      borrowing = create(:borrowing, borrow_date: Date.current - described_class::BORROW_TIME_LIMIT - 1.day)
      expect(described_class.active).to contain_exactly(borrowing)
    end

    it "excludes returned borrowings" do
      create(:borrowing, return_date: Date.current)
      expect(described_class.active).to be_empty
    end

    it "excludes returned overdue borrowings" do
      create(:borrowing, borrow_date: Date.current - described_class::BORROW_TIME_LIMIT - 5.days, return_date: Date.current)
      expect(described_class.active).to be_empty
    end
  end

  describe "due_date" do
    let(:borrow_date) { Date.new(2026, 10, 1) }

    it "is calculated from borrow_date before validation" do
      borrowing.borrow_date = borrow_date
      borrowing.valid?
      expect(borrowing.due_date).to eq(Date.new(2026, 10, 31))
    end

    it "overrides a manually assigned value on create" do
      borrowing.assign_attributes(borrow_date:, due_date: Date.new(2027, 1, 1))
      borrowing.save!
      expect(borrowing.reload.due_date).to eq(borrow_date + described_class::BORROW_TIME_LIMIT)
    end

    it "is recalculated when borrow_date changes" do
      borrowing = create(:borrowing, borrow_date:)
      borrowing.update!(borrow_date: Date.new(2026, 10, 10))
      expect(borrowing.reload.due_date).to eq(Date.new(2026, 11, 9))
    end

    it "is not changed when other attributes are updated" do
      borrowing = create(:borrowing, borrow_date:)
      borrowing.update!(return_date: Date.new(2026, 10, 10))
      expect(borrowing.reload.due_date).to eq(Date.new(2026, 10, 31))
    end
  end
end
