# app/controllers/accounts/expense_accounts_controller.rb

module Accounts
  class ExpenseAccountsController < ApplicationController
    include Authenticatable

    def index
      render json: ExpenseAccount.available_to(current_user).select(:id, :name).order(:id)
    end
  end
end
