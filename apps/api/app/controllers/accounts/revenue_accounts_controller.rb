# app/controllers/accounts/revenue_accounts_controller.rb

module Accounts
  class RevenueAccountsController < ApplicationController
    include TwoLevelAccountsActions

    private

    def accounts_service
      Accounts::RevenueAccountsService.new
    end

    def account_kind
      "revenue_account"
    end
  end
end
