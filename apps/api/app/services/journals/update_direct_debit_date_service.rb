# frozen_string_literal: true

module Journals
  class UpdateDirectDebitDateService
    def initialize(repository: UpdateDirectDebitDate.new)
      @repository = repository
    end

    def call(journal_id:, payment_date:, user_id:)
      ActiveRecord::Base.transaction do
        @repository.update_direct_debit_date!(journal_id: journal_id, payment_date: payment_date, user_id: user_id)
      end
    rescue UpdateDirectDebitDate::JournalNotFound
      raise JournalNotFoundError
    rescue UpdateDirectDebitDate::NotDirectDebitJournal
      raise NotDirectDebitJournalError
    rescue UpdateDirectDebitDate::PaymentDateBeforeJournalDate
      raise PaymentDateBeforeJournalDateError
    end
  end
end
