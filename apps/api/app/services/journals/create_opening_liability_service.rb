# frozen_string_literal: true

module Journals
  class CreateOpeningLiabilityService
    def initialize(repository: CreateOpeningLiability.new)
      @repository = repository
    end

    def call(journal_date:, liability_account_id:, amount:, payment_date:, user_id:)
      ActiveRecord::Base.transaction do
        @repository.create_opening_liability_balance!(
          journal_date: journal_date,
          liability_account_id: liability_account_id,
          amount: amount,
          payment_date: payment_date,
          user_id: user_id
        )
      end
    rescue CreateOpeningLiability::LiabilityAccountNotFound
      raise LiabilityAccountNotFoundError
    rescue CreateOpeningLiability::OpeningLiabilityAlreadyExists
      raise OpeningLiabilityAlreadyExistsError
    rescue CreateOpeningLiability::PaymentDateBeforeJournalDate
      raise PaymentDateBeforeJournalDateError
    rescue CreateOpeningLiability::CreditCardSettingNotFound
      raise CreditCardSettingNotFoundError
    end
  end
end
