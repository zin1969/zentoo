# frozen_string_literal: true

module Journals
  class CreateCashDepositService
    def initialize(repository: CreateCashDeposit.new)
      @repository = repository
    end

    def call(journal_date:, bank_account_id:, amount:, user_id:)
      ActiveRecord::Base.transaction do
        @repository.create_cash_deposit!(
          journal_date: journal_date,
          bank_account_id: bank_account_id,
          amount: amount,
          user_id: user_id
        )
      end
    rescue CreateCashDeposit::AssetAccountNotFound
      raise AssetAccountNotFoundError
    rescue CreateCashDeposit::CashAccountNotDetermined
      raise CashAccountNotDeterminedError
    end
  end
end
