# frozen_string_literal: true

# Enqueues a reminder email for every active borrowing due today or in 3 days, in a single bulk enqueue.
# Returns the number of reminders enqueued.
class ReturnReminderService
  DAYS_BEFORE_DUE = [ 3, 0 ].freeze

  def self.call(date: Date.current)
    new(date:).call
  end

  def initialize(date:)
    @date = date
  end

  def call
    borrowings = Borrowing.active.where(due_date: DAYS_BEFORE_DUE.map { |days| @date + days }).includes(:user, :item)
    jobs = borrowings.map do |borrowing|
      BorrowingMailer.delivery_job.new(BorrowingMailer.name, "return_reminder", "deliver_now", args: [ reminder_data(borrowing) ])
    end
    ActiveJob.perform_all_later(jobs)
    jobs.size
  end

  private

  def reminder_data(borrowing)
    {
      email: borrowing.user.email,
      first_name: borrowing.user.first_name,
      title: borrowing.item.title,
      due_date: borrowing.due_date,
      days_left: (borrowing.due_date - @date).to_i
    }
  end
end
