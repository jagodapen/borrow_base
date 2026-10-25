# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReturnDateReminderJob, type: :job do
  it "runs the return reminder service" do
    allow(ReturnReminderService).to receive(:call)

    described_class.perform_now

    expect(ReturnReminderService).to have_received(:call).with(no_args)
  end

  it "enqueues reminders for borrowings due today and in 3 days" do
    create(:borrowing, borrow_date: Date.current - Borrowing::BORROW_TIME_LIMIT)
    create(:borrowing, borrow_date: Date.current - Borrowing::BORROW_TIME_LIMIT + 3.days)
    create(:borrowing, borrow_date: Date.current)

    expect { described_class.perform_now }.to have_enqueued_mail(BorrowingMailer, :return_reminder).twice
  end

  it "is queued on the default queue" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue("default")
  end

  it "is scheduled every day at 10am" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
      .dig("production", "return_date_reminder")

    expect(task).to include("class" => described_class.name, "schedule" => "every day at 10am")
  end
end
