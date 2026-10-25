# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReturnReminderService do
  include ActiveJob::TestHelper

  let(:today) { Date.current }

  # Borrowings are due BORROW_TIME_LIMIT after borrow_date, so derive borrow_date from the wanted due date
  def borrowing_due_on(due_date, **attrs)
    create(:borrowing, borrow_date: due_date - Borrowing::BORROW_TIME_LIMIT, **attrs)
  end

  def reminder_for(borrowing, days_left:)
    { email: borrowing.user.email, first_name: borrowing.user.first_name, title: borrowing.item.title,
      due_date: borrowing.due_date, days_left: }
  end

  it "enqueues a 3 days reminder for an active borrowing due in 3 days" do
    borrowing = borrowing_due_on(today + 3.days)

    expect { described_class.call }
      .to have_enqueued_mail(BorrowingMailer, :return_reminder).with(reminder_for(borrowing, days_left: 3))
  end

  it "enqueues a due today reminder for an active borrowing due today" do
    borrowing = borrowing_due_on(today)

    expect { described_class.call }
      .to have_enqueued_mail(BorrowingMailer, :return_reminder).with(reminder_for(borrowing, days_left: 0))
  end

  it "returns the number of enqueued reminders" do
    borrowing_due_on(today)
    borrowing_due_on(today + 3.days)

    expect(described_class.call).to eq(2)
  end

  it "enqueues one reminder per matching borrowing" do
    2.times { borrowing_due_on(today + 3.days) }
    borrowing_due_on(today)

    expect { described_class.call }.to have_enqueued_mail(BorrowingMailer, :return_reminder).exactly(3).times
  end

  it "sends the reminder to the borrower's email" do
    user = create(:user, email: "reader@example.com")
    borrowing_due_on(today, user:)

    perform_enqueued_jobs { described_class.call }

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ "reader@example.com" ] ])
  end

  it "skips returned borrowings" do
    borrowing_due_on(today + 3.days, return_date: today)
    borrowing_due_on(today, return_date: today)

    expect { expect(described_class.call).to eq(0) }.not_to have_enqueued_mail(BorrowingMailer, :return_reminder)
  end

  [ -1, 1, 2, 4, 30 ].each do |days|
    it "skips active borrowings due in #{days} days" do
      borrowing_due_on(today + days.days)

      expect { expect(described_class.call).to eq(0) }.not_to have_enqueued_mail(BorrowingMailer, :return_reminder)
    end
  end

  it "skips overdue borrowings" do
    borrowing_due_on(today - 10.days)

    expect { described_class.call }.not_to have_enqueued_mail(BorrowingMailer, :return_reminder)
  end

  it "reminds only about matching borrowings among unrelated ones" do
    matching = borrowing_due_on(today + 3.days)
    borrowing_due_on(today + 5.days)
    borrowing_due_on(today, return_date: today)

    expect { described_class.call }
      .to have_enqueued_mail(BorrowingMailer, :return_reminder).with(reminder_for(matching, days_left: 3)).exactly(:once)
  end

  it "enqueues all reminders in a single bulk enqueue" do
    3.times { borrowing_due_on(today + 3.days) }
    allow(ActiveJob).to receive(:perform_all_later).and_call_original

    described_class.call

    expect(ActiveJob).to have_received(:perform_all_later).once.with(an_object_having_attributes(size: 3))
  end

  it "enqueues reminders on the mailer queue" do
    borrowing_due_on(today)

    expect { described_class.call }.to have_enqueued_mail(BorrowingMailer, :return_reminder).on_queue("default")
  end

  it "delivers without loading records again" do
    borrowing = borrowing_due_on(today)
    described_class.call
    borrowing.user.destroy!

    expect { perform_enqueued_jobs }.to change(ActionMailer::Base.deliveries, :size).by(1)
  end

  it "returns 0 when there are no borrowings" do
    expect(described_class.call).to eq(0)
  end

  it "computes due dates relative to the given date" do
    borrowing = borrowing_due_on(today - 2.days)

    expect { described_class.call(date: today - 5.days) }
      .to have_enqueued_mail(BorrowingMailer, :return_reminder).with(reminder_for(borrowing, days_left: 3))
  end
end
