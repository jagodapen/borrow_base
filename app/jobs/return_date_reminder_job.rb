# frozen_string_literal: true

# Runs daily (see config/recurring.yml) and reminds borrowers about upcoming and today's due dates.
class ReturnDateReminderJob < ApplicationJob
  queue_as :default

  def perform
    ReturnReminderService.call
  end
end
