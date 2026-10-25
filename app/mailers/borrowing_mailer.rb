# frozen_string_literal: true

class BorrowingMailer < ApplicationMailer
  # No real delivery is configured, so the payload is logged for inspection
  after_action :log_payload

  # reminder - plain data hash: email, first_name, title, due_date, days_left
  def return_reminder(reminder)
    @reminder = reminder

    mail(to: reminder[:email], subject: t(".subject", count: reminder[:days_left], title: reminder[:title]))
  end

  private

  def log_payload
    payload = { mailer: self.class.name, action: action_name, to: message.to, subject: message.subject,
                body: message.text_part&.body&.decoded }
    Rails.logger.info("Email payload: #{payload.to_json}")
  end
end
