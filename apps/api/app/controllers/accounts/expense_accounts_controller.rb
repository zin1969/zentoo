# app/controllers/accounts/expense_accounts_controller.rb

module Accounts
  class ExpenseAccountsController < ApplicationController
    include Authenticatable

    def index
      render json: current_user.expense_accounts.select(:id, :name).order(:id)
    end
  end
end
