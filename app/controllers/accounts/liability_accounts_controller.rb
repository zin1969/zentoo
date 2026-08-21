# app/controllers/accounts/liability_accounts_controller.rb

module Accounts
  class LiabilityAccountsController < ApplicationController
    def index
      accounts = LiabilityAccount.select(:id, :name, :liability_type).map do |account|
        {
          id: account.id,
          name: account.name,
          element_type: ElementType::LIABILITIES,
          payment_method_type: LiabilityAccount.liability_types.fetch(account.liability_type)
        }
      end

      render json: accounts
    end
  end
end
