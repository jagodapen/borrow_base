# frozen_string_literal: true

# Preview at http://localhost:3000/rails/mailers/borrowing_mailer
class BorrowingMailerPreview < ActionMailer::Preview
  def return_reminder_in_3_days
    BorrowingMailer.return_reminder(reminder(days_left: 3))
  end

  def return_reminder_due_today
    BorrowingMailer.return_reminder(reminder(days_left: 0))
  end

  private

  def reminder(days_left:)
    { email: "jane.doe@borrowbase.test", first_name: "Jane", title: "The Pragmatic Programmer",
      due_date: Date.current + days_left.days, days_left: }
  end
end
