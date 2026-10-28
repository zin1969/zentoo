# app/controllers/accounts/liability_accounts_controller.rb

module Accounts
  class LiabilityAccountsController < ApplicationController
    include Authenticatable

    def index
      accounts = current_user.liability_accounts.select(:id, :name, :liability_type).order(:id).map do |account|
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
