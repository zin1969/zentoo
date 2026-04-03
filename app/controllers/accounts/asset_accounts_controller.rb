# app/controller/accounts/asset_accounts_controller.rb

module Accounts
  class AssetAccountsController < ApplicationController
    def index
      render json: AssetAccount.select(:id, :name)
    end
  end
end
