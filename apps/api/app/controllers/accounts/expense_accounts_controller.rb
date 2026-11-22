# app/controllers/accounts/expense_accounts_controller.rb

module Accounts
  class ExpenseAccountsController < ApplicationController
    include TwoLevelAccountsActions

    private

    def accounts_service
      Accounts::ExpenseAccountsService.new
    end

    def account_kind
      "expense_account"
    end
  end
end
