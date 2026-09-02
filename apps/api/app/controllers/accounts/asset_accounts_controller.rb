# app/controller/accounts/asset_accounts_controller.rb

module Accounts
  class AssetAccountsController < ApplicationController
    def index
      accounts = AssetAccount.select(:id, :name, :asset_type).map do |account|
        {
          id: account.id,
          name: account.name,
          element_type: ElementType::ASSETS,
          payment_method_type: AssetAccount.asset_types.fetch(account.asset_type)
        }
      end

      render json: accounts
    end
  end
end
