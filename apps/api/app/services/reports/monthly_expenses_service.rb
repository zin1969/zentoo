# frozen_string_literal: true

module Reports
  class MonthlyExpensesService
    def initialize(repository: MonthlyExpenses.new)
      @repository = repository
    end

    def call(user_id:, month:)
      expenses = @repository.list(user_id: user_id, month: month)

      {
        month: month.strftime("%Y-%m"),
        total: expenses.sum(&:amount),
        items: expenses.map do |expense|
          { account_id: expense.account_id, account_name: expense.account_name, amount: expense.amount }
        end
      }
    end
  end
end
