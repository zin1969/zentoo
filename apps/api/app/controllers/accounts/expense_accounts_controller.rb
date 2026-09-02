# app/controllers/accounts/expense_accounts_controller.rb

module Accounts
  class ExpenseAccountsController < ApplicationController
    def index
      render json: ExpenseAccount.select(:id, :name)
    end
  end
end
