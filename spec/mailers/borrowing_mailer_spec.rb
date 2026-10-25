# frozen_string_literal: true

require "rails_helper"

RSpec.describe BorrowingMailer, type: :mailer do
  describe "#return_reminder" do
    let(:due_date) { I18n.l(Date.new(2026, 10, 31), format: :long) }

    def mail(days_left:)
      described_class.return_reminder(
        { email: "jane@example.com", first_name: "Jane", title: "Eloquent Ruby", due_date: Date.new(2026, 10, 31), days_left: }
      )
    end

    it "is sent to the borrower from the default sender" do
      expect(mail(days_left: 3)).to have_attributes(to: [ "jane@example.com" ], from: [ "from@example.com" ])
    end

    it "has text and html parts" do
      expect(mail(days_left: 3).parts.map(&:mime_type)).to contain_exactly("text/plain", "text/html")
    end

    context "when the item is due in 3 days" do
      subject(:message) { mail(days_left: 3) }

      it "says so in the subject" do
        expect(message.subject).to eq("Reminder: \"Eloquent Ruby\" is due in 3 days")
      end

      it "greets the borrower and states the due date in both parts" do
        [ message.text_part, message.html_part ].each do |part|
          body = part.body.decoded
          expect(body).to include("Hello Jane,")
          expect(body).to include("ends in 3 days (#{due_date})")
        end
      end
    end

    context "when the item is due today" do
      subject(:message) { mail(days_left: 0) }

      it "says so in the subject" do
        expect(message.subject).to eq("Reminder: \"Eloquent Ruby\" is due today")
      end

      it "states the due date in the body" do
        expect(message.text_part.body.decoded).to include("ends today (#{due_date})")
      end
    end

    context "when the item is due tomorrow" do
      it "uses the singular form" do
        expect(mail(days_left: 1).subject).to eq("Reminder: \"Eloquent Ruby\" is due tomorrow")
      end
    end

    it "logs the email payload" do
      allow(Rails.logger).to receive(:info).and_call_original

      mail(days_left: 3).message

      expect(Rails.logger).to have_received(:info).with(a_string_including(
        "Email payload:", '"to":["jane@example.com"]', '"subject":"Reminder: \"Eloquent Ruby\" is due in 3 days"',
        "Hello Jane,"
      ))
    end

    it "is delivered later as a job" do
      expect { mail(days_left: 3).deliver_later }.to have_enqueued_mail(described_class, :return_reminder)
    end
  end
end
